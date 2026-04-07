package Net::Nylas::Calendar::Calendar;

use Moose;
with 'Net::Nylas::Calendar::ToJson';

has [ qw(
    id grant_id name description location timezone
    read_only is_primary object hex_color hex_foreground_color
) ], is => 'ro';

=pod

{
  "id": "string",
  "grant_id": "string",
  "name": "string",
  "description": "string",
  "location": "string",
  "timezone": "string",
  "read_only": false,
  "is_primary": false,
  "object": "calendar",
  "hex_color": "#0000FF",
  "hex_foreground_color": "#FFFFFF"
}

=cut

__PACKAGE__->meta->make_immutable;

1;
