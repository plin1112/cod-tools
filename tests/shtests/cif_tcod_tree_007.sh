#!/bin/sh

set -ue

#BEGIN DEPEND------------------------------------------------------------------
INPUT_SCRIPT=scripts/cif_tcod_tree
INPUT_CIF=tests/inputs/aiida_exported_gzipped.cif
#END DEPEND--------------------------------------------------------------------

cif_tcod_tree=${INPUT_SCRIPT}

CIF=${INPUT_CIF}

BASENAME="`basename $0 .sh`"

TMP_DIR="./tmp-${BASENAME}"

mkdir ${TMP_DIR}

perl -lpe 's/(_audit_creation_method)/loop_ $1 "AiiDA version 0.9.1"/' ${CIF} \
    | ${cif_tcod_tree} --out ${TMP_DIR} || true

set -x

tree ${TMP_DIR}
cat ${TMP_DIR}/main.sh || true

set +x

rm -rf ${TMP_DIR}
