#!/bin/sh
d_gdcsrc=$(realpath $(dirname $0))
d_gccsrc=
d_update_gcc=0
top=$(pwd)

# -1. Make sure we know where the top-level GCC source directory is
if test -d "$d_gdcsrc/gcc" && test -d "$d_gdcsrc/gcc/d" && test -d "$d_gdcsrc/gcc/testsuite/gdc.gem"; then
    if test $# -eq 0; then
        echo "Usage: $0 [OPTION] PATH"
        exit 1
    fi
else
    echo "This script must be run from the top-level D source directory."
    exit 1
fi

# Read command line arguments
for arg in "$@"; do
    case "$arg" in
        --update) d_update_gcc=1 ;;
        *)
            if test -z "$d_gccsrc" && test -d "$arg" && test -d "$arg/gcc"; then
                d_gccsrc="$arg";
            else
                echo "error: '$arg' is not a valid option or path"
                exit 1
            fi ;;
    esac
done


# 0. Find out what GCC version this is
if grep version_string $d_gccsrc/gcc/version.c | grep -q '"3.4'; then
    gcc_ver=3.4
elif grep version_string $d_gccsrc/gcc/version.c | grep -q '"4.0'; then
    gcc_ver=4.0
elif grep -q -E '^4\.[1-9]+([^0-9]|$)' $d_gccsrc/gcc/BASE-VER; then
    gcc_ver=$(grep -oh -E '^4\.[0-9]+|$' $d_gccsrc/gcc/BASE-VER)
elif grep -q -E '^5\.[0-9]+([^0-9]|$)' $d_gccsrc/gcc/BASE-VER; then
    gcc_ver=5
elif grep -q -E '^6\.[0-9]+([^0-9]|$)' $d_gccsrc/gcc/BASE-VER; then
    gcc_ver=6
elif grep -q -E '^7\.[0-9]+([^0-9]|$)' $d_gccsrc/gcc/BASE-VER; then
    gcc_ver=7
else echo "cannot get gcc version"
    exit 1
fi
echo "found gcc version $gcc_ver"
gcc_patch_key=${gcc_ver}.x

# 1. Determine if this version of GCC is supported
if test ! -f "$d_gdcsrc/gcc/d/patches/patch-gcc-$gcc_patch_key"; then
    echo "This version of GCC ($gcc_ver) is not supported."
    exit 1
fi

# 1. Remove d sources from d_gccsrc if already exist
test -h "$d_gccsrc/gcc/d" && rm "$d_gccsrc/gcc/d"
test -d "$d_gccsrc/libphobos" && rm -r "$d_gccsrc/libphobos"
if test -e "$d_gccsrc/gcc/d" -o -e "$d_gccsrc/libphobos"; then
    echo "error: cannot update gcc source, please remove D sources by hand."
    exit 1
fi

d_test=$d_gccsrc/gcc/testsuite
# remove testsuite sources
test -d "$d_test/gdc.test" && rm -r "$d_test/gdc.test"
test -e "$d_test/lib/gdc.exp" && rm "$d_test/lib/gdc.exp"
test -e "$d_test/lib/gdc-dg.exp" && rm "$d_test/lib/gdc-dg.exp"
if test -e "$d_test/gdc.test" -o -e "$d_test/lib/gdc.exp" -o -e "$d_test/lib/gdc-dg.exp"; then
    echo "error: cannot update gcc source, please remove D testsuite sources by hand."
    exit 1
fi


# 2. Copy sources
ln -s "$d_gdcsrc/gcc/d" "$d_gccsrc/gcc/d"   && \
  mkdir "$d_gccsrc/libphobos"               && \
  cd "$d_gccsrc/libphobos"                  && \
  ../symlink-tree "$d_gdcsrc/libphobos"     && \
  cd "../gcc/testsuite"                     && \
  ../../symlink-tree "$d_gdcsrc/gcc/testsuite" && \
  cd $top


if test $d_update_gcc -eq 1; then
  echo "GDC update complete"
  exit 0
fi


# 3. Patch the top-level directory
#
# If the patch for the top-level Makefile.in doesn't take, you can regenerate
# it with:
#   autogen -T Makefile.tpl Makefile.def
#
# You will need the autogen package to do this. (http://autogen.sf.net/)
cd $d_gccsrc && \
  patch -p1 -i gcc/d/patches/patch-toplev-$gcc_patch_key && \
  cd $top || exit 1


# 4. Patch the gcc subdirectory
cd $d_gccsrc && \
  patch -p1 -i gcc/d/patches/patch-gcc-$gcc_patch_key && \
  patch -p1 -i gcc/d/patches/patch-versym-cpu-$gcc_patch_key && \
  patch -p1 -i gcc/d/patches/patch-versym-os-$gcc_patch_key && \
  cd $top || exit 1


echo "GDC setup complete."
exit 0
