#!/usr/bin/env perl

my $requirement_file = "deps.txt";
my @modules;

sub read_all
{
    print "[*] Reading module dependencies file ...\n";
    my $file = $_[0];
    if ( ( not defined $file ) || ( ! -e $file ) ) {
        print "[!] Error: Dependency file does not exists. \n";
        return -1;
    } else {
        open my $fp, '<', $file;
        while ( my $line = <$fp> ) {
            chomp $line;
            $_ = $line;
            if ( /^[^\n].+/ ) {
                print "[+] Dependency: $line\n";
                push @modules, $line;
            }
        }
    }

    return 0;
}

sub dep_install
{
    my $result = system "cpan install ", $_[0];
    if ( $result == 0 ) {
        print "[*] Dependency ", $_[0] . " has been installed.\n";
    } else {
        print "[!] Dependency ", $_[0] . " has failed installing.\n";
        return 1;
    }
    return 0;
}

sub install_all
{
    my @children_pids;
    foreach my $dep ( @modules ) {
        my $pid = fork();
        if (not $pid) {
            dep_install $dep;
        }
    }

    print "[*] Waiting for children process to terminate ...";
    foreach my $children ( @children_pids ) {
        waitpid($children, 0);
    }

    print "[+] Dependency installation has been completed.\n";
    return 0;
}

sub main
{
    read_all $requirement_file;
    install_all;
    return 0;
}

main;
