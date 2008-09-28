#!/usr/bin/perl

# dupesearch.pl - delete old debs in local mirror
# (c) 2003-2007 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.

use Term::ProgressBar 2.00;
use Config::File;

if (-e "/etc/sidmirror.conf") {
    $config_file_name = "/etc/sidmirror.conf";
}else{
    die ("Unable to read configuration file! Aborting...");
}

my $config_hash = Config::File::read_config_file($config_file_name);

if ($config_hash->{"LocalPath"}) {
    $rootdir = $config_hash->{"LocalPath"};
}else{
    die ("Invalid local repository path! Check sidmirror.conf");
}
if ($config_hash->{"Architecture"}) {
    @arch = split(/\,/, $config_hash->{"Architecture"});
}else{
    $arch[0] = "i386";
}

if ($ARGV[0] eq "-a") {
    $autorun = 1;
}
if ($ARGV[1] eq "-q") {
    $quiet = 1;
}

print "Getting directory listing for $rootdir\n" unless ($quiet);
`find $rootdir -iname "*.deb" -fprintf dirliststuff.txt "\%P\n"`;
print "Done!\n\n" unless ($quiet);

opendir (DISTDIR, "$rootdir/dists/sid/");
@dirlist = grep {!/^\./ && -d "$rootdir/dists/sid/$_"} readdir (DISTDIR);
closedir DISTDIR;

foreach $packagearch (@arch) {
  foreach (@dirlist) {
    my $packname = "$rootdir/dists/sid/$_/binary-$packagearch/Packages.gz";
    if (-s $packname) {
      print "Reading records from $_ ($packagearch) Packages.gz...\n" unless ($quiet);
      $oldcount = $#packfile;
      push (@packfile, `gunzip --to-stdout $packname`);
      print ((++$#packfile - $oldcount), " records read from $_\n\n") unless ($quiet);
    }
  }
}

print "Extracting filenames...\n" unless ($quiet);

foreach (@packfile) {
  if ($_ =~ /^Filename\: /) {
    push (@filenames, substr($_, 10));
  }
}

@usfiles = @filenames;
undef @packfile;
undef @filenames;
print "Read $#usfiles entries...\n\n" unless ($quiet);

open (DIRLIST, "dirliststuff.txt");
@dirlist = <DIRLIST>;
close DIRLIST;

print "Sorting arrays...\n" unless ($quiet);

@sorteddir = sort @dirlist;
@sortedusfiles = sort @usfiles;

print "Done!\n\n" unless ($quiet);

$countertotal = $#sorteddir + 1;
$currentcount = 0;

print "Searching for old files...\n" unless ($quiet);

if ($autorun != 1) {
    $progressbar = Term::ProgressBar->new($countertotal);
}

foreach (@sorteddir) {
  if ($autorun != 1) {
      $currentcount++;
      if ($currentcount >= $next_update) {
	  $next_update = $progressbar->update($currentcount);
      }
  }
  foreach $line (@sortedusfiles) {
    if ($line eq $_) {
      $keep = 1;
      last;
    }else {
      $keep = 0;
    }
  }
  if ($keep == 0) {
    push (@deleteme, $rootdir."/".$_);
  }
}

if ($countertotal >= $next_update && $autorun != 1) {
  $progressbar->update($countertotal);
}

if (! $quiet) {
  print "", ($#deleteme + 1), " main files found for deletion\n";
  print "Writing outputresults.txt... ";
}
open (OUTRESULTS, ">", "outputresults.txt");
print OUTRESULTS @deleteme;
close OUTRESULTS;
print "Done!\n\n" unless ($quiet);
