#!/usr/bin/perl

# parseoldsize.pl - calculate size of old debs
# (c) 2003-2007 Alex Malinovich (demonbane@the-love-shack.net)
# Released under the GPL
# See www.fsf.org for a full copy of the GPL.

open (OUTRES, "outputresults.txt");
@outres = <OUTRES>;
close OUTRES;

print ("Read ".($#outres + 1)." records...\n");

@filenames = @outres;

foreach (@filenames) {
  chomp;
  if (-e) {
    push (@deleteme, $_."\n");
    $count++;
  }
  $totalsize += -s;
}

if ($ARGV[0] eq "-h") {
  if ($totalsize > 1073741824) {
    printf ("%.2f", ($totalsize / 1073741824));
    print "GB\n";
  }elsif ($totalsize > 1048576) {
    printf ("%.2f", ($totalsize / 1048576));
    print "MB\n";
  }elsif ($totalsize > 1024) {
    printf ("%.2f", ($totalsize / 1024));
    print "KB\n";
  }else {
    print "$totalsize bytes\n";
  }
}else {
  print "$totalsize bytes\n";
}

if ($count > 0) {
  print "$count files still exist!\n";
  print "Writing undeleted files to deleteme.txt\n";
  open (DELETEME, ">", "deleteme.txt");
  print DELETEME @deleteme;
  close DELETEME;
}
