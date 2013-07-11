#--*-perl-*-------------------------------------------------------------
#$Author$
#$Date$
#$Revision$
#$URL$
#-----------------------------------------------------------------------
#*
# Basic symmetry operator algebra (addition, multiplication, etc.)
#**

package SymopAlgebra;

use strict;

require Exporter;
@SymopAlg::ISA = qw(Exporter);
@SymopAlg::EXPORT = qw( );

#
# Symop array contains the following values:
# my $symop = [
#     [ r11 r12 r13 t1 ]
#     [ r21 r22 r23 t2 ]
#     [ r31 r32 r33 t3 ]
#     [   0   0   0  1 ]
# ]
#

sub symop_mul($$)
{
    my ( $s1, $s2 ) = @_;

    my $klimit = @$s2 < @{$s1->[0]} ? @$s2 : @{$s1->[0]};
    my @result;
    for( my $i = 0; $i < @$s1; $i++ ) {
        for( my $j = 0; $j < @{$s2->[0]}; $j++ ) {
            $result[$i][$j] = 0;
            for( my $k = 0; $k < $klimit; $k++ ) {
                $result[$i][$j] += $s1->[$i][$k] * $s2->[$k][$j];
            }
        }
    }

    if( @$s2 == 3 && @{$s2->[0]} == 4 ) {
        # The last row of s1 is missing -- need to add t[1,2,3]' to
        # the result:
        for( my $k = 0; $k < 3; $k++ ) {
            $result[$k][3] += $s1->[$k][3];
        }
    } elsif( @$s2 == 4 && @{$s2->[0]} == 3 ) {
        # The last row is a 3-D translation vector:
        for( my $k = 0; $k < 3; $k++ ) {
            $result[3][$k] =
                $s2->[3][0] * $s1->[$k][0] +
                $s2->[3][1] * $s1->[$k][1] +
                $s2->[3][2] * $s1->[$k][2] +
                $s1->[3][$k];
        }
    }

    return wantarray ? @result : \@result;
}

sub symop_translate($$)
{
    my ( $symop, $vector ) = @_;
    return [ [ @{$symop->[0]} ], [ @{$symop->[1]} ], [ @{$symop->[2]} ],
	     [
	      $symop->[3][0] + $vector->[0],
	      $symop->[3][1] + $vector->[1],
	      $symop->[3][2] + $vector->[2]
	     ]
	   ];
}

sub matrix2x2_det($)
{
    my $m = $_[0];
    return $m->[0][0]*$m->[1][1] - $m->[0][1]*$m->[1][0];
}

sub symop_adjunct($$$)
{
    my ( $s, $row, $col ) = @_;
 
    my @matrix = ();
    my ( $i, $j, $mi, $mj );
    my $coef;

    die unless( $row >= 0 && $row < 3 );
    die unless( $col >= 0 && $col < 3 );

    $mi = $mj = 0;
    for( $i = 0; $i < 3; $i ++ ) {
        next if( $i == $row );
        $mj = 0;
        for( $j = 0; $j < 3; $j ++ ) {
	    next if( $j == $col );
            $matrix[$mi][$mj] = $s->[$i][$j];
            $mj ++;
        }
        $mi ++;
    }
    die unless( $mi == 2 );
    die unless( $mj == 2 );
    $coef = (($row + $col) % 2 == 0) ? +1.0 : -1.0;
    return $coef * matrix2x2_det( \@matrix );
}

sub symop_det( $ )
{
    my $s = $_[0];
    return
        + $s->[0][0] * $s->[1][1] * $s->[2][2]
        + $s->[1][0] * $s->[2][1] * $s->[0][2]
        + $s->[0][1] * $s->[1][2] * $s->[2][0]

        - $s->[0][2] * $s->[1][1] * $s->[2][0]
        - $s->[0][0] * $s->[1][2] * $s->[2][1]
        - $s->[0][1] * $s->[1][0] * $s->[2][2];
}

sub vector_negate($)
{
    return [ map {-$_} @{$_[0]} ];
}

sub symop_inv( $ )
{
    my $s = $_[0];
    my @ret;
    my $det = symop_det( $s );
    my ( $i, $j );

    for( $i = 0; $i < 3; $i++ ) {
        for( $j = 0; $j < 3; $j++ ) {
            $ret[$i][$j] = symop_adjunct($s,$j,$i) / $det;
        }
    }
    $ret[3] = vector_negate( matrix3x3_times_vector( \@ret, $s->[3] ));
    return \@ret;
}

sub symop_apply($$)
{
    my ( $symop, $vector ) = @_;
    $vector = matrix3x3_times_vector( $symop, $vector );
    return [
	    $vector->[0] + $symop->[3][0],
	    $vector->[1] + $symop->[3][1],
	    $vector->[2] + $symop->[3][2]
	   ];
}

1;