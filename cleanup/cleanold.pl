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

print ("Read ".($#filenames + 2)." entries...\n");

foreach (@filenames) {
  chomp;
  if (++$cnt < 20) {
    $delline = $delline." \"".$_."\"";
  }else {
    `rm $delline`;
    $delline = $_;
    $cnt = 0;
    $count += 19;
  }
}

`rm $delline`;
$count += $cnt;
print "$count files deleted\n";
if ($myinfile eq "deleteme.txt") {
  $cnt = unlink $myinfile;
}else {
  unlink "outputresults.txt";
}
@oldfiles = ("dirliststuff.txt", "outputresults.txt", "deleteme.txt");

foreach (@oldfiles) {
  if (-f $_) {
    if (unlink($_) != 1) {
      print "File $_ exists, but could not be deleted.\n";
    }
  }
}
