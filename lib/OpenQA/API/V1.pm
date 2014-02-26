# Copyright (C) 2014 SUSE Linux Products GmbH
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

package OpenQA::API::V1;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util 'hmac_sha1_sum';

sub auth {
    my $self = shift;
    my $headers = $self->req->headers;
    my $key = $headers->header('X-API-Key');
    my $hash = $headers->header('X-API-Hash');
    my $timestamp = $headers->header('X-API-Microtime');
    my $user;

    unless ($user = $self->current_user) {
        my $api_key = $self->db->resultset("ApiKeys")->find({key => $key});
        my $msg = $self->req->url->to_abs->to_string;
        if ($api_key && $self->_valid_hmac($hash, $msg, $timestamp, $api_key)) {
            $user = $api_key->user;
        }
    }

    return 1 if $user && $user->is_operator;

    $self->render(json => {error => "Not authorized"}, status => 403);
    return undef;
}

sub _valid_hmac {
    my $self = shift;
    my ($hash, $request, $timestamp, $api_key) = (shift, shift, shift, shift);

    if (time - $timestamp <= 10) {
        my $exp = $api_key->t_expiration;
        # It has no expiration date or it's in the future
        if (!$exp || $exp->epoch > time) {
            if (my $secret = $api_key->secret) {
                my $sum = hmac_sha1_sum($request.$timestamp, $secret);
                $self->app->log->debug("El cuerpo:".$request.$timestamp);
                $self->app->log->debug("ES *$sum* igual a *$hash*??");
                return 1 if $sum eq $hash;
            }
        }
    }

    return 0;
}

1;
