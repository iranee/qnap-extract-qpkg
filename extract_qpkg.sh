#!/bin/bash
#
# Script to extract the data within a QPKG file.
# (Another way to do this is using the QDK tool)
#
# A QPKG package starts with a short shell script followed by data blocks.
# The data blocks are usually *.tar.gz archives.
# This script extracts the header script until it finds a line starting with
# the word "exit". It then searches and extracts *.tar.gz parts by looking
# for gzip headers (starting with the byte sequence '1f 8b 08 00') in the file.
#
#
# Copyright 2015 Max Böhm
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
## 使用方法：extract_qpkg.sh 文件名.qpkg
## 注意不要存在qpkg同名的文件夹
## 修复59行 命令为 busybox od
## 修复65行 命令为 mkdir -p


trap 'echo "error in line ${LINENO}. Exiting."' ERR
set -e               # stop on error

if [ $# -lt 1 ]; then
  echo "usage $0 package.qpkg [destdir]"
  exit
fi

SRC="$1"
DEST="${2-${SRC%.*}}"

if [ -e $DEST ]; then echo "destdir '$DEST' must not already exist"; exit; fi

echo "SRC=$SRC, DEST=$DEST"
mkdir -p $DEST

# extract QPKG header script
#
echo "extracting '$DEST/header_script' ..."
sed '/^exit 1/q' <$SRC >$DEST/header_script

SKIP=`wc -c < $DEST/header_script`
echo "$SKIP bytes."

dd if=$SRC bs=$SKIP skip=1 of=$DEST/payload status=none

PART_NAMES=(control data extra)   # convention for QPKG packages generated by QDK
i=0
for a in `busybox od -t x1 -w4 -Ad -v $DEST/payload | grep '1f 8b 08 00' | awk '{print $1}'`; do
  PART="$DEST/${PART_NAMES[$i]}"
  echo "- extracting '$PART.tar.gz' at offset $a into '$PART' ..."
  dd if=$DEST/payload bs=$a skip=1 of=$PART.tar.gz status=none
  gunzip -f $PART.tar.gz || [ $? -eq 2 ] 
  mkdir -p $PART
  tar xf $PART.tar -C $PART
  i=$((i+1))
done
rm $DEST/payload