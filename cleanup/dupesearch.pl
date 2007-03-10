#!/usr/bin/perl

# dupesearch.pl - delete old debs in local mirror
# (c) 2003-2005 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.

use Term::ProgressBar 2.00;
use ConfigFile;

if (-e "/etc/sidmirror.conf") {
    $config_file_name = "/etc/sidmirror.conf";
}else{
    die ("Unable to read configuration file! Aborting...");
}

my $config_hash = ConfigFile::read_config_file($config_file_name);

if ($config_hash->{"LocalPath"}) {
    $rootdir = $config_hash->{"LocalPath"};
}else{
    die ("Invalid local repository path! Check sidmirror.conf");
}
if ($config_hash->{"Architecture"}) {
    $arch = $config_hash->{"Architecture"};
}else{
    die ("Invalid architecture specified! Check sidmirror.conf");
}

if ($ARGV[0] eq "-a") {
    $autorun = 1;
}

print "Getting directory listing for $rootdir\n";
`find $rootdir -iname "*.deb" -fprintf dirliststuff.txt "\%P\n"`;
print "Done!\n\n";

opendir (DISTDIR, "$rootdir/dists/sid/");
@dirlist = grep {!/^\./ && -d "$rootdir/dists/sid/$_"} readdir (DISTDIR);
closedir DISTDIR;

foreach (@dirlist) {
  my $packname = "$rootdir/dists/sid/$_/binary-$arch/Packages.gz";
  if (-s $packname) {
    print "Reading records from $_ Packages.gz...\n";
    $oldcount = $#packfile;
    push (@packfile, `gunzip --to-stdout $packname`);
    print ((++$#packfile - $oldcount), " records read from $_\n\n");
  }
}

print "Extracting filenames...\n";

foreach (@packfile) {
  if ($_ =~ /^Filename\: /) {
    push (@filenames, substr($_, 10));
  }
}

@usfiles = @filenames;
undef @packfile;
undef @filenames;
print "Read $#usfiles entries...\n\n";

open (DIRLIST, "dirliststuff.txt");
@dirlist = <DIRLIST>;
close DIRLIST;

print "Sorting arrays...\n";

@sorteddir = sort @dirlist;
@sortedusfiles = sort @usfiles;

print "Done!\n\n";

$countertotal = $#sorteddir + 1;
$currentcount = 0;

print "Searching for old files...\n";

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

print "", ($#deleteme + 1), " main files found for deletion\n";
print "Writing outputresults.txt... ";
open (OUTRESULTS, ">", "outputresults.txt");
print OUTRESULTS @deleteme;
close OUTRESULTS;
print "Done!\n\n";
