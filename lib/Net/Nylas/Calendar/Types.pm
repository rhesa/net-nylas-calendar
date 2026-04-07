package Net::Nylas::Calendar::Types;

use Type::Library
    -base,
    -declare => qw(
        NylasCalendar CalendarId
        Event When Participant Organizer
        CBool
    );
use Type::Utils -all;
use Types::Standard -types;

class_type NylasCalendar, { class => 'Net::Nylas::Calendar::Calendar'  };
class_type Event,         { class => 'Net::Nylas::Calendar::Event'     };
class_type When,          { class => 'Net::Nylas::Calendar::When'      };
class_type Participant,   { class => 'Net::Nylas::Calendar::Participant' };
class_type Organizer,     { class => 'Net::Nylas::Calendar::Organizer' };

declare CBool, as Bool, where { !!$_ || !$_ };
declare CalendarId, as Str, where { 1 };

coerce CBool,
    from Any, via { !!$_ };

coerce CalendarId,
    from NylasCalendar, via { $_->id };
coerce CalendarId,
    from Str, via { $_ };

coerce NylasCalendar,
    from HashRef, via { 'Net::Nylas::Calendar::Calendar'->new($_) };
coerce Event,
    from HashRef, via { 'Net::Nylas::Calendar::Event'->new($_) };
coerce When,
    from HashRef, via { 'Net::Nylas::Calendar::When'->new($_) };
coerce Participant,
    from HashRef, via { 'Net::Nylas::Calendar::Participant'->new($_) };
coerce Organizer,
    from HashRef, via { 'Net::Nylas::Calendar::Organizer'->new($_) };

1;
