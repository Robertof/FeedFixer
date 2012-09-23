#!/usr/bin/env perl
# Utils module for FeedFixer

package FeedFixer::Utils;
use strict;
use warnings;
use IO::Socket::INET;
use URI;
use Carp qw(cluck);
use base 'Exporter';

$SIG{"__WARN__"} = sub {
    # logfile dumper utility
    eval { no warnings; ref (\&{main::justLog}) eq "CODE" };
    main::justLog ($_[0]) if not $@;
    print STDERR $_[0];
};
use constant {
    # $cookies param in *_get_request functions
    NO_COOKIES         => -1,
    # user agents for *_get_request subs
    UA_MOZILLA_FIREFOX => "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:15.0) Gecko/20100101 Firefox/15.0.1",
    UA_NONE            => -1,
    # response codes
    REQ_FAILED         => -1
};
our @EXPORT_OK   = ('NO_COOKIES', 'UA_MOZILLA_FIREFOX', 'UA_NONE', 'REQ_FAILED');
our %EXPORT_TAGS = ( 
    all => [ 'NO_COOKIES', 'UA_MOZILLA_FIREFOX', 'UA_NONE', 'REQ_FAILED' ],
    ua  => [ 'UA_MOZILLA_FIREFOX', 'UA_NONE' ],
    misc=> [ 'NO_COOKIES', 'REQ_FAILED' ]
);

# you don't need to init this, static usage ftw
# just use FeedFixer::Utils->function(params)
sub d
{
    # save error to logfile, then croak
    # see line 11
    cluck $_[1] . "\n";
    exit 1;
}

sub w
{
    cluck $_[1] . "\n";
    return 1;
}

# get a complete path from an URI object
sub get_path_from_uri
{
    return unless ref ($_[1]) =~ /^URI/;
    return ($_[1]->path ? $_[1]->path : "/") .
           ($_[1]->query ? "?" . $_[1]->query : "") .
           ($_[1]->fragment ? "#" . $_[1]->fragment : "");
}

# wrap a function (useful for inline conditions)
# usage: condition && (wrap (&some_function_which_may_return_0()) && other)
sub wrap
{
    return 1;
}

# 
# HTTP GET request function
# for the params see the first line in the sub
sub do_http_get_request
{
    my ($self, $url, $cookies, $useragent) = @_;
    # check URL
    my $uo = URI->new ($url);
    return if not $uo;
    return if ($uo->scheme !~ /^https?$/);
    $uo->secure && $self->d ("Secure URLs are not supported right now.");
    # everything ok, let's proceed
    # open request
    my $sock = IO::Socket::INET->new (
        PeerAddr => $uo->host,
        PeerPort => 80,
        Proto    => "tcp"
    ) or ( $self->w ("Cannot open the socket for " . $uo->host . ": ${!}") && return REQ_FAILED );
    # write
    print $sock "GET " . $self->get_path_from_uri ($uo) . " HTTP/1.1\n";
    print $sock "Host: " . $uo->host . "\n";
    print $sock "Cookie: ${cookies}\n" if $cookies ne NO_COOKIES;
    print $sock "User-Agent: ${useragent}\n" if $useragent ne UA_NONE;
    print $sock "Connection: close\n\n";
    # dump answer
    my $data; $data .= $_ while (<$sock>);
    $data =~ s/\015?\012/\n/g; # replace \r\n with \n
    # separate headers from normal text
    my @separated = split /\n\n/, $data;
    # [0] contains the headers, [1],[2],... the text
    my ($headers, $txt) = (shift (@separated), join ("\n\n", @separated));
    # remove first and last line from $txt
    my @_txt = split /\n/, $txt;
    shift @_txt; pop @_txt;
    # join again
    $txt = join ("\n", @_txt);
    # check HTTP response code
    my $rescode = substr ($headers, 9, 3);
    # parse headers
    my @head    = split /\n/, $headers;
    my $headersH = {};
    foreach (@head)
    {
        if ($_ =~ /^([^\s]+):\s([^\$]+)$/)
        {
            my ($h, $c) = (lc ($1), $2);
            if (exists $headersH->{$h} and ref ($headersH->{$h}) ne "ARRAY")
            {
                my $cV = $headersH->{$h};
                $headersH->{$h} = [ $cV , $c ];
            }
            elsif (exists $headersH->{$h} and ref ($headersH->{$h}) eq "ARRAY")
            {
                push @{$headersH->{$h}}, $c;
            }
            elsif (not exists $headersH->{$h})
            {
                $headersH->{$h} = $c;
            }
        }
    }
    if ($rescode !~ /^[32][0-9][0-9]$/)
    {
        $self->w ("WARNING: " . $uo->host . " returned HTTP rescode ${rescode}."
                  ."\nThis may cause a lot of problems if the script using this"
                  . " don't expect a bad response.");
        return REQ_FAILED;
    }
    elsif ($rescode =~ /^30[1237]$/)
    {
        if (exists $headersH->{"location"})
        {
            main::justLog (
                sprintf (
                    "[UtilsReq] Redirecting from '%s' to '%s'..",
                    $uo->as_string,
                    $headersH->{"location"}
                )
            );
            return $self->do_http_get_request ($headersH->{"location"}, $cookies, $useragent);
        }
        else
        {
            $self->w ("WARNING: " . $uo->host . " returned a redirection code ("
                      . $rescode . ") but it didn't give me a location. Req"
                      . " failed!");
            return REQ_FAILED;
        }
    }
    elsif ($rescode =~ /^2/)
    {
        # request ok
        return [ $rescode, $headersH, $txt ];
    }
    else
    {
        $self->w ("WARNING: " . $uo->host . " request failed..");
        return REQ_FAILED;
    }
}

sub in_array
{
    my ($self, $elm, $array) = @_;
    foreach (@{$array})
    {
        return 1 if (lc ($elm) eq lc ($_));
    }
    return 0;
}

1;
