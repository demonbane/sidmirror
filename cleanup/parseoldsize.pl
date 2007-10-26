#!/usr/bin/perl

# parseoldsize.pl - calculate size of old debs
# (c) 2003-2007 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.

open (OUTRES, "outputresults.txt");
@outres = <OUTRES>;
close OUTRES;

print ("Read ".($#outres + 1)." records... ");

@filenames = @outres;

foreach (@filenames) {
  chomp;
  if (-e) {
    push (@deleteme, $_."\n");
    $count++;
  }
  $totalsize += -s;
}

if ($ARGV[0] eq "-h" && $count > 0) {
  if ($totalsize > 1073741824) {
    $totalsize = sprintf("%.2fGB", ($totalsize / 1073741824));
  }elsif ($totalsize > 1048576) {
    $totalsize = sprintf ("%.2fMB", ($totalsize / 1048576));
  }elsif ($totalsize > 1024) {
    $totalsize = sprintf ("%.2fKB", ($totalsize / 1024));
  }
}

if ($count > 0) {
  print "$count files still exist! ($totalsize)\n";
  print "Writing undeleted files to deleteme.txt\n";
  open (DELETEME, ">", "deleteme.txt");
  print DELETEME @deleteme;
  close DELETEME;
}else{
  print "no files to delete!\n";
}
