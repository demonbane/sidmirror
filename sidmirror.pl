#!/usr/bin/perl

# sidmirror.pl - Sid mirroring script
# (c) 2003-2005 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.
#
# $server - Server to sync main, contrib, and non-free with.
#
# $serverpath - Path to the debian directory on $server. This is
# USUALLY /debian. Some mirrors, such as rsync.kernel.org, use a
# different path, such as /mirrors/debian.
#
# $rootdir - root directory for main, contrib, and non-free. This will
# become identical to $server::debian/ after the first rsync.
#
# $installpath - directory where this script resides. Since all of the
# paths used for logs and associated programs are relative, we need to
# chdir to the home directory first to make sure that nothing breaks
# if this is being run from a cron job.
#
# $arch - the architecture to copy. This has been tested with i386 and
# amd64. All other architectures SHOULD work but they have not been
# tested.

use Term::ProgressBar 2.00;
use Fcntl;
use ConfigFile;

if (-e "/etc/sidmirror.conf") {
  my $config_hash = ConfigFile::read_config_file("/etc/sidmirror.conf");

  if ($config_hash->{"Mirror"}) {
    $server = $config_hash->{"Mirror"};
  }else {
    $server = "http.us.debian.org";
  }

  if ($config_hash->{"RepositoryPath"}) {
    $serverpath = $config_hash->{"RepositoryPath"};
    if (substr($serverpath, 0, 1) eq "/") {
    	$serverpath=substr($serverpath, 1);
	print "Modifying RepositoryPath to \"$serverpath\"\n";
    }
  }else {
    $serverpath = "debian";
  }

  if ($config_hash->{"LocalPath"}) {
    $rootdir = $config_hash->{"LocalPath"};
  }else {
    $rootdir = "./debian";
  }

  if ($config_hash->{"Architecture"}) {
    $arch = $config_hash->{"Architecture"};
  }else {
    $arch = "i386";
  }

  if ($config_hash->{"LogDir"}) {
    $logdir = $config_hash->{"LogDir"};
  }else {
    $logdir = "./logs";
  }

  if ($config_hash->{"InstallPath"}) {
    $installpath = $config_hash->{"InstallPath"};
  }else{
    $installpath = "./";
  }
}else {
  print "sidmirror configuration file (sidmirror.conf) not found!\n";
  print "Please create an appropriate configuration file and try again.\n\n";
  exit 0;
}

$autorun = 0;
$force = 0;

while (@ARGV) {
  my $option = shift (@ARGV);
  if ($option eq "--help" || $option eq "-h") {
    print "Usage: sidmirror [OPTION]\n";
    print "Update local Debian Sid mirror.\n\n";
    print "  -h, --help      display this screen and exit\n";
    print "  -a, --auto      run in automated mode; no user intervention required\n";
    print "  -f, --force     ignore lockfile and run anyway (DANGEROUS!)\n\n";
    exit 0;
  }elsif ($option eq "-a" || $option eq "--auto") {
    $autorun = 1;
  }elsif ($option eq "-f" || $option eq "--force") {
    $force = 1;
  }elsif ($option =~ /^\w/) {
    $server = $option;
  }else {
    print STDERR "sidmirror: invalid option -- $option\n";
    print STDERR "Try \`sidmirror --help\' for more information.\n";
    exit 1;
  }
}

chdir $installpath || die ("Unable to enter InstallPath!\n");

###############################################################
## Create a lockfile to prevent multiple instances from running
###############################################################
if (!sysopen(FH, "sidmirror.lock", O_WRONLY|O_EXCL|O_CREAT, 0400)) {
  if (-M "sidmirror.lock" >= 1.5) {
    print "WARNING!!!\nStale lockfile found. Removing... ";
    do {
      $pid = `pidof -x -o %PPID sidmirror`;
      if ($pid ne "\n") {`kill -9 $pid`};
    }while ($pid ne "\n");
    unlink "sidmirror.lock";
    print "Done!";
    sysopen(FH, "sidmirror.lock", O_WRONLY|O_EXCL|O_CREAT, 0400) || die $!;
  }elsif ($force) {
    print "Lockfile found, but proceeding anyway as you request.\n";
    print "!!! DANGER !!!\n";
    print "This may break your mirror! You have been warned!\n\n";
  }else {
    print "Lockfile found, aborting!\n";
    exit 0;
  }
}

################################################
## Download the newest Packages.gz from $server
################################################
do {
  print "Retrieving newest Packages.gz from $server...\n";
  $errcode = system(
		    "rsync -P --recursive --times --verbose --compress --delete-excluded --include \"/main/binary-$arch/Packages.gz\" --include \"/contrib/binary-$arch/Packages.gz\" --include \"/non-free/binary-$arch/Packages.gz\" --include \"/main/debian-installer/binary-$arch/Packages.gz\" --include \"*/\" --exclude \"*\" $server\:\:$serverpath/dists/sid/ $rootdir/dists/sid/ 1> Package.output 2> Package.error"
		   );
  $errcode /= 256;
  $retry = "false";
  if ($errcode > 0 && $autorun != 1) {
    print "\nError! Rsync failed with an exit code of $errcode! Check Package.error for details.\n<A>bort, <R>etry, or <C>ontinue? [A/r/c] ";
    $proceed = <STDIN>;
    $proceed = uc($proceed);
    chomp $proceed;
    if ($proceed eq "C") {
      $retry = "false";
    }elsif ($proceed eq "R") {
      $retry = "true";
    }else {
      unlink ("sidmirror.lock");
      exit 1;
    }
  }else {
    print "\nDone!\n\n";
  }
}while ($retry eq "true");

# TODO: Either make this more failsafe or get rid of it and
# use a user-defined array.
opendir (DISTDIR, "$rootdir/dists/sid/");
@dirlist = grep {!/^\./ && -d "$rootdir/dists/sid/$_"} readdir (DISTDIR);
closedir DISTDIR;

# Dirty hack, but necessary to include debian installer.
push (@dirlist, "main/debian-installer");

foreach (@dirlist) {
  my $packname = "$rootdir/dists/sid/$_/binary-$arch/Packages.gz";
  if (-s $packname) {
    print "Reading records from $_ Packages.gz...\n";
    $oldcount = $#packfile;
    push (@packfile, `gunzip --to-stdout $packname`);
    print (($#packfile + 1 - $oldcount), " records read from $_\n\n");
    push (@modch, "$packname");
  }
}

undef $flagvar;
foreach (@packfile) {
  if ($flagvar) {
    $filenames{$flagvar} = substr ($_, 6);
    undef $flagvar;
  }
  if ($_ =~ /^Filename\: /) {
    $flagvar = substr($_, 10);
    chomp $flagvar;
  }
}

print "Done!\n\n";

# TODO: _POSSIBLY_ have the script compare the files already present to
# the names and sizes listed in Packages.gz and exclude ones that match.
# This should speed things up quite a bit when there's a small number of
# packages to be updated. I'll have to think about this one.

# Generate a list of files we need from the standard distrib
print "Generating includefile...\n";

open (INCLUDEFILE, ">", "includefile");

if (-e "static-includes") {
    open (SINCLUDES, "static-includes");
    @sincludes = <SINCLUDES>;
    print "Inserting ", $#sincludes, " records from static-includes...\n";
    close SINCLUDES;
    print INCLUDEFILE @sincludes;
}

if ($autorun != 1) {
    print "Number of files: ",(scalar keys %filenames),"\n";
    $progressbar = Term::ProgressBar->new(scalar keys %filenames);
}

$includedfiles = 0;
$currentcount = 0;
foreach (keys %filenames) {
  if ($autorun != 1) {
      $currentcount++;
      if ($currentcount >= $next_update) {
	  $next_update = $progressbar->update($currentcount);
      }
  }
  if (!-e "$rootdir/$_") {
    print INCLUDEFILE $_."\n";
    $includedfiles++;
    $sizetoget += $filenames{$_};
  }
}

if ($currentcount >= $next_update && $autorun != 1) {
  $next_update = $progressbar->update($currentcount);
}

close INCLUDEFILE;
print $includedfiles, " records written\n";
printf ("%.2f", ($sizetoget / 1048576));
print "MB to download\n";
$ussize = $sizetoget;

if ($autorun != 1) {
  print "Run cleanup scripts now? [Y/n] ";
  $proceed = <STDIN>;
  $proceed = uc($proceed);
  chomp $proceed;
}
if ($proceed ne "N") {
  if ($autorun != 1) {
      system ("./cleanup/dupesearch.pl");
  }else{
      system ("./cleanup/dupesearch.pl -a");
  }
  system ("./cleanup/parseoldsize.pl -h");
  system ("./cleanup/cleanold.pl");
}

if ($autorun != 1) {
  print "\nReady to begin mirroring operation.\n";
  print "Need to download ";
  printf ("%.2f", $ussize / 1048576);
  print "MB of packages. Continue? [Y/n] ";
  $proceed = <STDIN>;
  $proceed = uc($proceed);
  chomp $proceed;
  if ($proceed eq "N") {
    print "\nExiting...\n\n";
    unlink ("sidmirror.lock");
    exit 0;
  }
}

chmod 0555, @modch;

if (-s "./includefile") {
  print "Starting rsync with $server...\n";
  `echo Starting rsync with $server... > $logdir/rsync.log`;
  $retcode = system ("rsync --recursive --links --hard-links --times --verbose --compress --include \"*/\" --include-from=includefile --exclude \"*\" $server\:\:$serverpath/ $rootdir/ >> $logdir/rsync.log 2>&1");
  $retcode /= 256;
  `echo End rsync with $server... exit value = $retcode >> $logdir/rsync.log`;
}else {
  print "No files to fetch from $server... skipping...\n";
  `echo No files to fetch from $server... skipping... >> $logdir/rsync.log`;
}
if ($retcode > 0) {
  print "An error was encountered while performing the rsync operation! The exit code reported was $retcode. Please check $logdir/rsync.log.0 for details.\n\n";
}else {
  print "rsync completed successfully!\n\n";
}

`savelog $logdir/rsync.log`;

chmod 0755, @modch;

if ($retcode == 0 && $errcode == 0) {
  print "All operations completed successfully!\n\n";
}else {
  print "Errors encountered during operation! Please check Package.error and $logdir/rsync.log.0 for details!\n\n";
}

unlink "sidmirror.lock";
