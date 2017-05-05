#!/usr/bin/env perl
# ====================================================================
# GitHub Sync (ghubs) is a perl script to sync with one user profile
# from github.com using GitHub API.
# ====================================================================

use strict;
use LWP::UserAgent;
use JSON;
use Getopt::ArgParse;
use Data::Dumper;
use Cwd;

sub header
{
    print "=" x 40 . "\n";
    print "  GHubS - version 0.02\n";
    print "  made by zc00l\n";
    print "=" x 40 . "\n";
    return 0;
}

header;

# Json object creation
my $json = JSON->new->allow_nonref;

# Argument processing
my $ap = Getopt::ArgParse->new_parser(
    prog => 'GHubS',
    description => 'GitHubSync is a perl script to sync your remote account to a local folder.',
    epilog=> 'This software is licensed under MIT license.',
);
$ap->add_arg('--user', '-u', help=>'User to query for repositories', required=> 1);
$ap->add_arg('--token', '-t', help=>'OAuth2 token to use for authentication', required=>1);
$ap->add_arg('--blacklist', '-b', help=>'Blacklist file of unwanted repositories', required=>0);
$ap->add_arg('--local', '-l', help=> 'Local folder to download files', required=>0);
$ap->add_arg('--private', '-p', help=> 'Sync private repositories. Default: Public only', required=> 0, type=> 'Bool');
my $args = $ap->parse_args( @ARGV );

# Program global variables
my $blacklist_file = $args->blacklist;
my @blacklist_repo;
my $github_api = "https://api.github.com";
my $ua = LWP::UserAgent->new;
my $OAuth2_token = $args->token;
my $repo_data = undef;
my @children_pids;

sub get_blacklisted
{
    if (not defined $blacklist_file) {
        return 0;
    }

    my $blacklist_name = $_[0];
    open my $fp, '<', $blacklist_file;
    while ( my $line = <$fp> ) {
        chomp $line;
        push @blacklist_repo, $line;
    }
    close $fp;
    return 0;
}

sub authenticate()
{
    if (not defined $OAuth2_token) {
        return 1;
    }

    my $req = HTTP::Request->new(GET => $github_api);
    $req->header('Authorization' => "token " . $OAuth2_token);
    print "[+] Sending authorization request to GitHub ...\n";
    my $resp = $ua->request($req);

    if ($resp->is_success) {
        print "[*] Authorization suceeded.\n";
    } else {
        print "[!] Error sending authorization request.\n";
        print "HTTP error code: ", $resp->code . "\n";
        print "HTTP error message: ", $resp->message . "\n";
        exit 1;
    }
    return 0;
}

sub get_repo_data()
{
    my $user = $args->user;
    my $data_size;
    my $req;
    if ( $args->private ) {
        print "[+] Fetching private repositories ...\n";
        $req = HTTP::Request->new(GET => $github_api . "/user/repos?type=private");
        $req->header('Authorization' => "token " . $OAuth2_token);
    } else {
        $req = HTTP::Request->new(GET => $github_api . "/users/$user/repos?type=all");
        $req->header('Authorization' => "token " . $OAuth2_token);
    }

    #my $req = HTTP::Request->new(GET => $github_api . "/user/repos?type=owner");
    #$req->header('Authorization' => "token " . $OAuth2_token);
    my $resp = $ua->request( $req );
    if ( $resp->is_success ) {
        $data_size = length $resp->content;
        print "[*] Received $data_size bytes from remote endpoint.\n";
        $repo_data = $json->decode( $resp->content );
    } else {
        print "HTTP error: ", $resp->code . "\n";
        print "HTTP messg: ", $resp->message . "\n";
    }
    return 0;
}

sub work
{
    # Clone a remote repository if it do not exists.
    my ( $url, $name, $branch ) = @_;
    if ( (! -e $name) || (! -d $name) ) {
        system(`git clone $url > /dev/null 2>&1`);
        #print "git clone $url\n";
        #sleep 10;
        return 0;
    }

    if ( (-e $name) && (-d $name) ) {
        chdir $name;
        system(`git pull origin $branch > /dev/null 2>&1`);
        #print "git pull origin $branch\n";
        #sleep 10;
    }
    return 0;
}

sub chloc
{
    if (not defined $args->local) {
        return -1;
    }

    my $folder = $args->local;
    my $current = getcwd;
    if ( ! -d $folder ) {
        print "[!] Local folder does not exists.\n";
        exit 0;
    } else {
        if ( $current ne $folder ) {
            print "[*] Moving to folder $folder ...\n";
            chdir $folder;
        }
    }
}

sub check_blacklist
{
    if ( not defined $_[0] ) {
        print "[!] check_blacklist: no arguments.\n";
        exit 0;
    }

    my $repo = $_[0];
    foreach my $blacklisted ( @blacklist_repo ) {
        if ( $blacklisted eq $repo ) {
            print "[!] Ignoring repository $repo.\n";
            exit 0;
        }
    }
    return 0;
}

sub control
{
    # Control the number of processes spawned by the program.
    my $max_proc = 2;
    my $proc_num = scalar @children_pids;
    if ( $proc_num > $max_proc ) {
        my $pid = waitpid(-1, 0);
        pop @children_pids, $pid;

    }
    return 0;
}

sub main()
{
    # Authenticate, get repository data, and change to local directory
    # if it is specified.
    get_blacklisted;
    authenticate();
    get_repo_data();
    chloc;

    foreach my $item ( @$repo_data ) {
        my %repo = %$item;
        my $git_url = $repo{'git_url'};
        my $git_name = $repo{'name'};
        my $git_branch = $repo{'default_branch'};
        my $pid = fork();
        die if not defined $pid;
        if (not $pid) {
            check_blacklist $git_name;
            work $git_url, $git_name, $git_branch;
            print "[*] Repository $git_name has been synchronized.\n";
            exit 0;
        } else {
            push @children_pids, $pid;
            control;
        }
    }

    wait();
    print "[*] GHubS synchronization has been completed.\n";
    return 0;
}

main();
