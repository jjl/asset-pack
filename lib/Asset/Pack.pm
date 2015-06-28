use 5.010000;
use strict;
use warnings;

package Asset::Pack;

use Path::Tiny qw( path );
use MIME::Base64 qw( encode_base64 decode_base64 );

our $VERSION = '0.000001';

# ABSTRACT: Easily pack assets into Perl Modules that can be fat-packed

use parent qw(Exporter);
our @EXPORT_OK = qw(
  module_rel_path module_full_path
  pack_asset write_module unpack_asset
);

our @EXPORT = qw(write_module unpack_asset);

sub module_rel_path {
  my ($module) = @_;
  $module =~ s{::}{/}g;
  return "${module}.pm";
}

sub module_full_path {
  my ($module, $libdir) = @_;
  return path($libdir)->child(module_rel_path($module));
}

sub pack_asset {
  my ( $module, $path ) = @_;
  my $content = encode_base64( path($path)->slurp_raw );
  return <<"EOF";
package $module;
use Asset::Pack;
our \$content = unpack_asset;
__DATA__
$content
EOF
}

sub write_module {
  my ( $source, $module, $libdir ) = @_;
  my $dest = module_full_path( $module, $libdir );
  $dest->parent->mkpath;    # mkdir
  $dest->spew_utf8( pack_asset( $module, $source ) );
  return;
}

sub unpack_asset {
  my $caller = caller;
  my $fh     = do {
    no strict 'refs';
    \*{"${caller}::DATA"};
  };
  my $content = join q[], $fh->getlines;
  $content =~ s/\s+//g;
  return decode_base64($content);
}

1;
__END__

=head1 SYNOPSIS

    #!/usr/bin/env perl
    use Asset::Pack;
    # lib/MyApp/Asset/FooJS.pm will embed assets/foo.js
    write_module('assets/foo.js' 'MyApp::Asset::FooJS' 'lib');

=head1 DESCRIPTION

This module allows you to construct Perl modules containing the content of
arbitrary files, which may then be installed or fat-packed.

In most cases, this module is not what you want, and you should use a
C<File::ShareDir> based system instead, but C<File::ShareDir> based systems are
inherently not fat-pack friendly.

However, if you need embedded, single-file applications, aggregating not only
Perl Modules, but templates, JavaScript and CSS, this tool will make some of
your work easier.

=head1 NOTES

Generated files are dependent on the Asset::Pack module. I might remove this
requirement in future but it's not a concern for me for the project I wrote
this for. Patches welcome.

=func C<module_rel_path>

  module_rel_path(module) -> file_path (string)

  module_rel_path("Foo::Bar") # "Foo/Bar.pm"

Turns a module name (e.g. 'Foo::Bar') into a file path relative to a library
directory root

=func C<module_full_path>

  module_full_path(module, libdir) -> file_path (string)

  module_full_path("Foo::Bar", "./") # "./Foo/Bar.pm"

Turns a module name and a library directory into a file path

=func C<pack_asset>

  pack_asset($module, $path) -> byte_string

  pack_asset("Foo::Bar", "./foo.js") # "ZnVuY3Rpb24oKXt9"

Given a module name and the path of an asset to be packed, returns the new
module with the content packed into the data section

=func C<write_module>

  write_module($source, $module, $libdir)

  write_module("./foo.js", "Foo::Bar", "./")
  # ./Foo/Bar.pm now contains base64 encoded copy of foo.js

Given a source asset path, a module name and a library directory, packs the
source into a module named C<$module> and saves it in the right place relative
to C<$libdir>

See L</SYNOPSIS> and try it out!

=func C<unpack_asset>

  unpack_asset -> byte_string

  package Foo;
  my $content = unpack_asset; # "function(){}"
  __DATA__
  ZnVuY3Rpb24oKXt9

Returns the contents of C<DATA> in the callers context, decoded.
