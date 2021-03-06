use strict;
use warnings;

use Test::More;

# ABSTRACT: Test _pack_metadata

use Asset::Pack qw( pack_asset );
use Test::TempDir::Tiny qw( tempdir );
use Path::Tiny qw( path );
use Test::Differences qw( eq_or_diff );

sub mk_pack {
  my ( $file, $packed_class ) = @_;
  local $@;
  do $file or die "Did not get true return, $@";
  my $stash_contents = {};
  no strict 'refs';
  my $stash = \%{ $packed_class . '::' };

  for my $key ( keys %{$stash} ) {
    local $@;
    eval {
      my $value = ${ $stash->{$key} };
      $stash_contents->{$key} = $value;
      1;
    } and next;
    warn "$@ while scalarizing $key";
  }
  return $stash_contents;
}

my $tempdir = tempdir();
my $binfile = path( $tempdir, 'binary_ranges.bin' );
{
  my $fh = $binfile->openw_raw;

  $fh->print("\nDouble\n");
  for my $first ( 0 .. 255 ) {
    for my $second ( 0 .. 255 ) {
      print {$fh} chr for $first, $second;
      print {$fh} "\n" if ( ( $first * 255 ) + $second ) % 10 == 0;
    }
  }
  close $fh;
}
my $packed_data = pack_asset( 'Test::X::BinaryRanges', "$binfile" );
my $content_file = path( $tempdir, "TestXBinaryRanges.pm" );
$content_file->spew_raw($packed_data);
my $unpack = mk_pack( "$content_file", 'Test::X::BinaryRanges' );
eq_or_diff( $binfile->slurp_raw, $unpack->{content}, 'Class contains binary data un-damaged', );
done_testing;
