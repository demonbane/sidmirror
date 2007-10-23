#!/usr/bin/perl

# cleanold.pl - delete old debs in local mirror
# (c) 2003-2007 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.

if (-e "deleteme.txt") {
  $myinfile = "deleteme.txt";
}else {
  $myinfile = "outputresults.txt";
}

open (INFILE, "$myinfile");
@filenames = <INFILE>;
close INFILE;

print ("Read ".($#filenames + 1)." entries...\n");

$count = unlink(@filenames);

if ($count != $#filenames + 1) {
  print "$count files deleted - ",($filenames + 1 - $count)," files remain\n";
}else {
  print "$count files deleted\n";
}

@oldfiles = ("dirliststuff.txt", "outputresults.txt", "deleteme.txt");

foreach (@oldfiles) {
  if (-f $_) {
    if (unlink($_) != 1) {
      print "File $_ exists, but could not be deleted.\n";
    }
  }
}
