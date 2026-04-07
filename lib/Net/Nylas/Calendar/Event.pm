package Net::Nylas::Calendar::Event;

use Moose;
with 'Net::Nylas::Calendar::ToJson';
use Kavorka;
use Types::Standard qw( Str Int ArrayRef HashRef Enum );
use Net::Nylas::Calendar::Types qw( CBool When Participant Organizer );
use Net::Nylas::Calendar::When;
use Net::Nylas::Calendar::Participant;
use Net::Nylas::Calendar::Organizer;

has [ qw( id grant_id calendar_id ical_uid html_link object ) ], is => 'ro';
has [ qw( created_at updated_at ) ], is => 'ro', isa => Int;

has [ qw( title description location ) ], is => 'rw';
has recurrence => is => 'rw', isa => ArrayRef[Str];
has reminders  => is => 'rw', isa => HashRef;
has metadata   => is => 'rw', isa => HashRef;

has when         => is => 'rw', isa => When,              coerce => 1;
has organizer    => is => 'rw', isa => Organizer,         coerce => 1;
has participants => is => 'rw', isa => ArrayRef[Participant],
                   coerce => 1, default => sub { [] };

has busy       => is => 'rw', isa => CBool, coerce => 1;
has status     => is => 'rw', isa => Enum[qw( confirmed tentative cancelled )];
has visibility => is => 'rw', isa => Enum[qw( public private )];

=pod

{
  "id": "string",
  "grant_id": "string",
  "calendar_id": "string",
  "ical_uid": "string",
  "html_link": "string",
  "object": "event",
  "created_at": 1234567890,
  "updated_at": 1234567890,
  "title": "string",
  "description": "string",
  "location": "string",
  "status": "confirmed",
  "busy": true,
  "visibility": "public",
  "when": {
    "start_time": 1234567890,
    "end_time":   1234567890,
    "start_timezone": "America/New_York",
    "end_timezone":   "America/New_York"
  },
  "organizer": { "email": "string", "name": "string" },
  "participants": [
    {
      "email": "string",
      "name": "string",
      "status": "yes",
      "comment": "string",
      "phone_number": "string"
    }
  ],
  "recurrence": [ "RRULE:FREQ=WEEKLY" ],
  "reminders": {
    "use_default": true,
    "overrides": [
      { "reminder_minutes": 10, "reminder_method": "popup" }
    ]
  },
  "metadata": { "key": "value" }
}

=cut

__PACKAGE__->meta->make_immutable;

1;
