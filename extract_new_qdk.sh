#!/bin/bash

SIGN_CERT=sign.crt
SIGN_KEY=sign.key

PREFIX=qpkg_workspace
EXTRACT_PATH=qpkg_content

len_to_binary() {
        len=$1
        byte4="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte3="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte2="\\`printf 'x%02x' $((len%256))`"
        len=$((len/256))
        byte1="\\`printf 'x%02x' $((len%256))`"
        printf "$byte1$byte2$byte3$byte4"
}

get_offset() {
        offsets="$(/bin/sed -n '1,/^exit 1/{
s/^script_len=\([0-9]*\).*$/\1/p
s/^offset.*script_len[^0-9]*\([0-9]*\).*$/\1/p
s/^offset.*offset[^0-9]*\([0-9]*\).*$/\1/p
/^exit 1/q
}' "${QPKG}")"
        script_len=`echo $offsets|cut -f 1 -d " "`
        raw_offset1=`echo $offsets|cut -f 2 -d " "`
        raw_offset2=`echo $offsets|cut -f 3 -d " "`
        offset1=$((script_len+raw_offset1))
        offset2=$((offset1+raw_offset2))
}

extract_qdk() {
        mkdir -p $PREFIX/$EXTRACT_PATH
        get_offset
        echo $script_len $raw_offset1 $raw_offset2 $offset1 $offset2
        echo $(((raw_offset2+1024)/1024))
        dd if=$QPKG bs=$script_len count=1 > $PREFIX/head
        if grep data.tar.7z  $PREFIX/head >/dev/null; then
                is7z=1
        fi
        dd if=$QPKG bs=$script_len skip=1 |/bin/tar -xO | /bin/tar -xzv -C  $PREFIX/$EXTRACT_PATH
        dd if=$QPKG bs=$offset1 skip=1 | /bin/cat | /bin/dd bs=1024 of=$PREFIX/$EXTRACT_PATH/data.tar.gz
        busybox truncate -s $raw_offset2 $PREFIX/$EXTRACT_PATH/data.tar.gz

        mkdir $PREFIX/$EXTRACT_PATH/data
        if [ "$is7z" == "1" ]; then
                mv $PREFIX/$EXTRACT_PATH/data.tar.gz $PREFIX/$EXTRACT_PATH/data.tar.7z
                7z x -so $PREFIX/$EXTRACT_PATH/data.tar.7z | tar x -C $PREFIX/$EXTRACT_PATH/data
        else
                tar xf $PREFIX/$EXTRACT_PATH/data.tar.gz -C $PREFIX/$EXTRACT_PATH/data
        fi

        tail -c 100 $QPKG> $PREFIX/tail
}

pack_qdk() {
        # control.tar.gz
        tar czf $PREFIX/control.tar.gz -C $PREFIX/$EXTRACT_PATH built_info package_routines  qinstall.sh  qpkg.cfg
        tar cf $PREFIX/control.tar -C $PREFIX control.tar.gz
        new_offset1=`stat -c "%s" $PREFIX/control.tar`
        new_offset2=`stat -c "%s" $PREFIX/$EXTRACT_PATH/data.tar.gz`
# update control.tar offset
        sed -i "s/^\(.*script_len \+ \)$raw_offset1\(.*\)\$/\1$new_offset1\2/g" $PREFIX/head
# update data.tar.gz offset
# assume the longest number will not expect confict.
        sed -i "s/^\(.*\)$raw_offset2\(.*\)\$/\1$new_offset2\2/g" $PREFIX/head
# update /bin/dd bs=1024 count=
        bcount=$(((new_offset2+1024)/1024))
        sed -i "s/^\(.*bs=1024 count=\)[0-9]*\(.*\)\$/\1$bcount\2/g" $PREFIX/head

# update script_len
        script_len=`stat -c "%s" $PREFIX/head`
        sed -i "s/^script_len=.*\$/script_len=$script_len/g" $PREFIX/head

# assemble
        cat $PREFIX/head $PREFIX/control.tar $PREFIX/$EXTRACT_PATH/data.tar.gz > $PREFIX/qpkg.bin

# sign
        openssl sha1 -binary $PREFIX/qpkg.bin | openssl cms -sign  -nodetach -binary -signer $SIGN_CERT -inkey $SIGN_KEY > $PREFIX/qpkg.bin.sign

 # tail
        sign_len=`stat -c "%s" $PREFIX/qpkg.bin.sign`
        echo -n "QDK" >> $PREFIX/qpkg.bin
        printf "\xFE" >> $PREFIX/qpkg.bin
        len_to_binary $sign_len >> $PREFIX/qpkg.bin
        cat $PREFIX/qpkg.bin.sign >> $PREFIX/qpkg.bin
        printf "\xFF" >> $PREFIX/qpkg.bin
        cat $PREFIX/tail >> $PREFIX/qpkg.bin
 # update encrypt
        fullsize=`stat -c "%s" $PREFIX/qpkg.bin`
        encrypt=$((fullsize * 3589 + 1000000000))
        echo -n "$encrypt" | dd of=$PREFIX/qpkg.bin seek=$((fullsize-60)) bs=1 conv=notrunc
        mv $PREFIX/qpkg.bin $PREFIX/$QPKG

}

usage() {
        echo "Usage:"
        echo "$0 extract foldername pkgname             extract package to foldername"
        echo "$0 pack foldername pkgname                pack files under folder to foldername"
        exit 1
}

if [ "$#" -eq "2" ]; then
        usage
fi

PREFIX="$2"
QPKG=$3

case "$1" in
        extract)
                extract_qdk
                ;;
        pack)
                pack_qdk
                echo "please find it in $PREFIX/$QPKG"
                ;;
        *)
                usage
esac
