#!/bin/sh
##
# Tests the way error messages are formed when using COD::UserMessage
# module in command-line perl as well as reading from SDTIN as input file.
##

#BEGIN DEPEND------------------------------------------------------------------
INPUT_MODULE='src/lib/perl5/COD/UserMessage.pm'
#END DEPEND--------------------------------------------------------------------

echo "test error" | \
perl -e 'use COD::UserMessage qw( error );' \
     -e 'while (<>) {' \
     -e '    error($0, $ARGV, undef, $_, undef )' \
     -e '}'
