package Net::Nylas;

=head1 NAME

Net::Nylas - Base class for Nylas API access

=cut

use Moose;
use Kavorka;
use JSON::XS;
use WWW::JSON;

has api_key            => is => 'ro', predicate => 'has_api_key';
has oauth_access_token => is => 'ro', predicate => 'has_token';
has grant_id           => is => 'ro', required  => 1;

has authentication => is => 'ro', lazy => 1,
    predicate => 'has_auth', builder => '_build_authentication';

has _service => is => 'ro', lazy => 1, builder => '_build_service';

method _build_service {
    WWW::JSON->new(
        base_url         => 'https://api.us.nylas.com/v3/grants/' . $self->grant_id,
        post_body_format => 'JSON',
        authentication   => $self->authentication,
        json             => JSON::XS->new->utf8->allow_nonref->allow_blessed->convert_blessed,
    );
}

method _build_authentication {
    my $token = $self->has_api_key      ? $self->api_key
              : $self->has_token        ? $self->oauth_access_token
              : die "Need an api_key or oauth_access_token";
    return sub { $_[1]->header(Authorization => "Bearer $token") };
}

__PACKAGE__->meta->make_immutable;

1;
