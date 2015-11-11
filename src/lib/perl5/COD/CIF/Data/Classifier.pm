#------------------------------------------------------------------------------
#$Author$
#$Date$ 
#$Revision: 1434 $
#$URL$
#------------------------------------------------------------------------------
#*
#  Classify a CIF structure -- find out if it is organic compound,
#  inorganic, mineral, etc.
#**

package COD::CIF::Data::Classifier;

use strict;
use warnings;
use COD::CIF::Data qw( get_cell get_symmetry_operators );
use COD::CIF::Data::SymmetryGenerator qw( symop_generate_atoms );
use COD::Fractional qw( symop_ortho_from_fract );
use COD::Spacegroups::Symop::Algebra qw( symop_vector_mul );
use COD::Spacegroups::Symop::Parse qw( symop_from_string modulo_1 );
use COD::Algebra::Vector qw( distance
                             matrix_vector_mul
                             vdot
                             vector_sub );

require Exporter;
our @ISA = qw( Exporter );
our @EXPORT_OK = qw(
    cif_class_flags
    cif_has_C_bonds
);

sub get_atoms( $$$ );

sub length_of_fractional_vector( $$ );
sub distance_fractional( $$$ );

my $has_C_H_bond_flag = "has_C_H_bond";
my $has_C_C_bond_flag = "has_C_C_bond";

my $too_close_distance = 0.3; # Angstroems

sub cif_class_flags( $$$$ )
{
    my ( $datablock, $filename, $atom_properties, $bond_safety_margin ) = @_;

    my @flags = ();

    @flags = cif_has_C_bonds
        ( $datablock, $filename, $atom_properties, $bond_safety_margin );

    return wantarray ? sort @flags : join( ",", sort @flags );
}

sub cif_has_C_bonds( $$$$ )
{
    my ( $datablock, $filename, $atom_properties, $bond_safety_margin ) = @_;

    my %flags; # accumulate flags that will be returned

    my $C_H_covalent_distance =
        $atom_properties->{"C"}{covalent_radius} +
        $atom_properties->{"H"}{covalent_radius} +
        $bond_safety_margin;

    my $C_C_covalent_distance =
        $atom_properties->{"C"}{covalent_radius} * 2 +
        $bond_safety_margin;

    my $atoms = get_atoms( $datablock, $filename, "_atom_site_label" );

    ## print $datablock->{name}, " ", int(@$atoms), "\n";

    ## use COD::Serialise;
    ## serialiseRef( $atoms );

    my $symops =
        get_symmetry_operators( $datablock, $filename );

    my @symop_matrices = map { symop_from_string($_) } @{$symops};

    ## use COD::Serialise;
    ## serialiseRef( $symops );

    my @cell =
        get_cell( $datablock->{values}, $filename, $datablock->{name} );

    if( !@cell || !defined $cell[0] || @cell < 6 ) {
        return 0;
    }

    my $f2o = symop_ortho_from_fract(  @cell );

    my $g = metric_tensor_from_cell( @cell );

    ## use COD::Serialise;
    ## serialiseRef( $g );

    my $sym_atoms =
        symop_generate_atoms( \@symop_matrices, $atoms, $f2o );

    ## use COD::Serialise;
    ## serialiseRef( $sym_atoms );

    # Search for a C-H or C-C bond:

    for my $i (0..$#$atoms) {
        my $atom1 = $atoms->[$i];
        next unless $atom1->{atom_type} eq "C";

        # First, let's try bonds with untranslated symmetry equivalent
        # atoms, since they are the most probable -- asymmetric units
        # usually contain atoms that are close to each other in a
        # molecule:
        for my $j ($i+1..$#$sym_atoms) {
            my $atom2 = $sym_atoms->[$j];
            next unless
                $atom2->{atom_type} eq "H" || 
                $atom2->{atom_type} eq "C";
            next if
                $atom1->{assembly} eq $atom2->{assembly} &&
                $atom1->{group} ne $atom2->{group} &&
                $atom1->{group} ne '.' && $atom2->{group} ne '.';

            my $interatomic_distance =
                distance( $atom1->{coordinates_ortho},
                          $atom2->{coordinates_ortho} );

            next if $interatomic_distance < $too_close_distance;

            ## my $distance = distance_fractional( $atom1->{coordinates_fract},
            ##                                     $atom2->{coordinates_fract},
            ##                                     $g );
            ## 
            ## print ">>> $interatomic_distance, $distance\n"
            ##     if abs($interatomic_distance - $distance) > 1E-6;

            if( $atom2->{atom_type} eq "H" &&
                $interatomic_distance < $C_H_covalent_distance ) {
                ## print ">>> found C-H bond $interatomic_distance " .
                ##     "$atom1->{atom_name}-$atom2->{atom_name}\n";
                ## use COD::Serialise;
                ## serialiseRef( [ $atom1, $atom2, $interatomic_distance,
                ##                 $C_H_covalent_distance  ] );
                $flags{$has_C_H_bond_flag} = 1;
                return keys %flags if int(keys %flags) >= 2;
            }
            if( $atom2->{atom_type} eq "C" &&
                $interatomic_distance < $C_C_covalent_distance ) {
                ## print ">>> found C-C bond $interatomic_distance \n";
                ## use COD::Serialise;
                ## serialiseRef( [ $atom1, $atom2, $interatomic_distance,
                ##                 $C_H_covalent_distance  ] );
                $flags{$has_C_C_bond_flag} = 1;
                return keys %flags if int(keys %flags) >= 2;
            }
        }
        # If we did not find bond to untranslated atoms, let's try
        # +/-1 translation:
        for my $j (0..$#$sym_atoms) {
            my $atom2 = $sym_atoms->[$j];
            next unless
                $atom2->{atom_type} eq "H" || 
                $atom2->{atom_type} eq "C";
            next if
                $atom1->{assembly} eq $atom2->{assembly} &&
                $atom1->{group} ne $atom2->{group} &&
                $atom1->{group} ne '.' && $atom2->{group} ne '.';

            for my $dx (-1, 0, 1) {
            for my $dy (-1, 0, 1) {
            for my $dz (-1, 0, 1) {
                my @shifted_fractionals = ( $atom2->{coordinates_fract}[0] + $dx,
                                            $atom2->{coordinates_fract}[1] + $dy,
                                            $atom2->{coordinates_fract}[2] + $dz );

                my $distance = distance_fractional( $atom1->{coordinates_fract},
                                                    \@shifted_fractionals,
                                                    $g );

                next if $distance < $too_close_distance;

                if( $atom2->{atom_type} eq "H" &&
                    $distance < $C_H_covalent_distance ) {
                    ## use COD::Serialise;
                    ## serialiseRef( [ $atom1, $atom2, $interatomic_distance,
                    ##                 $C_H_covalent_distance  ] );
                    $flags{$has_C_H_bond_flag} = 1;
                    return keys %flags if int(keys %flags) >= 2;
                }
                if( $atom2->{atom_type} eq "C" &&
                    $distance < $C_C_covalent_distance ) {
                    ## use COD::Serialise;
                    ## serialiseRef( [ $atom1, $atom2, $interatomic_distance,
                    ##                 $C_H_covalent_distance  ] );
                    $flags{$has_C_C_bond_flag} = 1;
                    return keys %flags if int(keys %flags) >= 2;
                }
            }}}
        }
    }

    return keys %flags;
}

# ============================================================================ #
# Gets atom descriptions, as used in this module, from a CIF datablock.
#
# Returns an array of
#
#   $atom_info = {
#                   atom_name => "C1_2",
#                   atom_type => "C",
#                   assembly  => "A", # "."
#                   group     => "1", # "."
#                   occupancy => 1.0,
#                   cif_multiplicity  => 96,
#                   coordinates_fract => [1.0, 1.0, 1.0],
#                   coordinates_ortho => [1.0, 1.0, 1.0],
#              }
#

sub get_atoms($$$)
{
    my ( $dataset, $filename, $loop_tag ) = @_;

    my $values = $dataset->{values};

    my @unit_cell =
        get_cell( $values, $filename, $dataset->{name} );

    if( !@unit_cell || !defined $unit_cell[0] || @unit_cell < 6 ) {
        return;
    }

    my $ortho_matrix = symop_ortho_from_fract( @unit_cell );

    my @atoms;

    for my $i ( 0 .. $#{$values->{$loop_tag}} ) {

        my @fractional_coordinates_modulo_1 = 
            map { s/\(\d+\)\s*$//; modulo_1($_) }
            ( $values->{_atom_site_fract_x}[$i],
              $values->{_atom_site_fract_y}[$i],
              $values->{_atom_site_fract_z}[$i] );

        my $atom = {
            atom_name => $values->{$loop_tag}[$i],
            atom_type => exists $values->{_atom_site_type_symbol} ?
                $values->{_atom_site_type_symbol}[$i] : undef,
            coordinates_fract => \@fractional_coordinates_modulo_1,
        };

        if( !defined $atom->{atom_type} || $atom->{atom_type} eq '?' ) {
            if( length($atom->{atom_name}) < 2 ) {
                $atom->{atom_type} = $atom->{atom_name};
            } else {
                my $tentative_type = substr( $atom->{atom_name}, 0, 2 );
                my $lc_type = ucfirst( lc( $tentative_type ));

                use COD::AtomProperties;
                if( exists $COD::AtomProperties::atoms{$lc_type} ) {
                    $atom->{atom_type} = $lc_type;
                } else {
                    $atom->{atom_type} = substr( $lc_type, 0, 1 );
                }

            }
        }

        if( $atom->{atom_type} =~ m/^([A-Za-z]{1,2})/ ) {
            $atom->{atom_type} = ucfirst( lc( $1 ));
        }

        $atom->{coordinates_ortho} =
            symop_vector_mul( $ortho_matrix, $atom->{coordinates_fract} );

        if( defined $values->{_atom_site_occupancy} ) {
            if( $values->{_atom_site_occupancy}[$i] ne '?' &&
                $values->{_atom_site_occupancy}[$i] ne '.' ) {
                $atom->{occupancy} = $values->{_atom_site_occupancy}[$i];
                $atom->{occupancy} =~ s/\(\d+\)\s*$//;
            } else {
                $atom->{occupancy} = 1;
            }
        }

        if( defined $values->{_atom_site_symmetry_multiplicity} &&
            $values->{_atom_site_symmetry_multiplicity}[$i] ne '?' ) {
            $atom->{cif_multiplicity} =
                $values->{_atom_site_symmetry_multiplicity}[$i];
        }

        if( exists $values->{"_atom_site_disorder_assembly"}[$i]) {
            $atom->{"assembly"} =
                $values->{"_atom_site_disorder_assembly"}[$i];
        } else {
            $atom->{"assembly"} = ".";
        }

        if( exists $values->{"_atom_site_disorder_group"}[$i] ) {
            $atom->{"group"} = $values->{"_atom_site_disorder_group"}[$i];
        } else {
            $atom->{"group"} = ".";
        }

        push( @atoms, $atom );
    }

    return \@atoms;
}

my $Pi = 4 * atan2(1,1);

sub metric_tensor_from_cell
{
    my @cell = @_;
    my ($a, $b, $c) = @cell[0..2];
    my ($alpha, $beta, $gamma) = map {$Pi * $_ / 180} @cell[3..5];
    my ($ca, $cb, $cg) = map {cos} ($alpha, $beta, $gamma);

    my $g = [
        [ $a * $a, $a * $b * $cg, $a * $c * $cb ],
        [ 0,       $b * $b,       $b * $c * $ca ],
        [ 0,             0,       $c * $c ]
        ];

    $g->[1][0] = $g->[0][1];
    $g->[2][0] = $g->[0][2];
    $g->[2][1] = $g->[1][2];

    return $g;
}

sub length_of_fractional_vector( $$ )
{
    my ( $v, $g ) = @_;
    return vdot( $v, matrix_vector_mul( $g, $v ));
}

sub distance_fractional( $$$ )
{
    my ( $v1, $v2, $g ) = @_;
    return sqrt( length_of_fractional_vector( vector_sub($v1, $v2), $g ));
}

1;