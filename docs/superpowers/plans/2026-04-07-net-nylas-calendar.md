# Net::Nylas::Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone CPAN-publishable Perl wrapper for the Nylas Calendar API v3, natively exposing Nylas field names and semantics.

**Architecture:** `Net::Nylas` is the base module handling auth/HTTP via WWW::JSON; `Net::Nylas::Calendar` extends it with calendar and event CRUD. Supporting classes (`Calendar`, `Event`, `When`, `Participant`, `Organizer`) are plain Moose objects coercible from HashRefs via a `Type::Library`.

**Tech Stack:** Perl, Moose, Kavorka, Types::Standard, Type::Library, WWW::JSON, JSON::XS, DateTime, DateTime::Format::ISO8601, Try::Tiny, Dist::Zilla

---

## File Map

| File | Responsibility |
|---|---|
| `lib/Net/Nylas.pm` | Auth, `grant_id`, WWW::JSON `_service` builder |
| `lib/Net/Nylas/Calendar.pm` | Calendar + event CRUD methods |
| `lib/Net/Nylas/Calendar/ToJson.pm` | Moose role: `TO_JSON` |
| `lib/Net/Nylas/Calendar/Types.pm` | Type::Library: all types + coercions |
| `lib/Net/Nylas/Calendar/Calendar.pm` | Calendar model |
| `lib/Net/Nylas/Calendar/Organizer.pm` | Organizer model |
| `lib/Net/Nylas/Calendar/Participant.pm` | Participant model |
| `lib/Net/Nylas/Calendar/When.pm` | When model: 4 subtypes, get/set with DateTime |
| `lib/Net/Nylas/Calendar/Event.pm` | Event model |
| `dist.ini` | Dist::Zilla distribution config |
| `Changes` | Changelog |

---

### Task 1: Scaffold the repo

**Files:**
- Create: `dist.ini`
- Create: `Changes`

- [ ] **Step 1: Create `dist.ini`**

```ini
name    = Net-Nylas-Calendar
version = 0.01
abstract = Access Nylas Calendars using the v3 API
author  = Rhesa Rozendaal <rhesa@cpan.org>
license = Perl_5
copyright_holder = Rhesa Rozendaal

[@Classic]

[Prereqs]
DateTime                  = 0
DateTime::Format::ISO8601 = 0
JSON::XS                  = 0
Kavorka                   = 0
LWP::Protocol::https      = 0
Moose                     = 0
Try::Tiny                 = 0
Types::Standard           = 0
WWW::JSON                 = 0

[GithubMeta]
issues = 1
```

- [ ] **Step 2: Create `Changes`**

```
Revision history for Net-Nylas-Calendar

0.01  2026-04-07
    - Initial release
```

- [ ] **Step 3: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add dist.ini Changes
git commit -m "Scaffold dist.ini and Changes"
```

---

### Task 2: `ToJson` role

**Files:**
- Create: `lib/Net/Nylas/Calendar/ToJson.pm`

- [ ] **Step 1: Create the file**

```perl
package Net::Nylas::Calendar::ToJson;

use Moose::Role;
use Kavorka;

method TO_JSON {
    return { %$self };
}

1;
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add ToJson role"
```

---

### Task 3: `Organizer` and `Participant` models

**Files:**
- Create: `lib/Net/Nylas/Calendar/Organizer.pm`
- Create: `lib/Net/Nylas/Calendar/Participant.pm`

- [ ] **Step 1: Create `Organizer.pm`**

```perl
package Net::Nylas::Calendar::Organizer;

use Moose;
with 'Net::Nylas::Calendar::ToJson';

has [ qw( email name ) ], is => 'ro';

1;
```

- [ ] **Step 2: Create `Participant.pm`**

```perl
package Net::Nylas::Calendar::Participant;

use Moose;
with 'Net::Nylas::Calendar::ToJson';
use Types::Standard qw( Enum );

has [ qw( email name comment phone_number ) ], is => 'ro';
has status => is => 'ro', isa => Enum[qw( yes no maybe noreply )];

1;
```

- [ ] **Step 3: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add Organizer and Participant models"
```

---

### Task 4: `When` model

**Files:**
- Create: `lib/Net/Nylas/Calendar/When.pm`

The Nylas `when` field has four subtypes detected by which fields are present:
- `time`: has `time` field (Unix timestamp int)
- `timespan`: has `start_time` and `end_time` (Unix timestamps)
- `date`: has `date` field (YYYY-MM-DD string)
- `datespan`: has `start_date` and `end_date` (YYYY-MM-DD strings)

- [ ] **Step 1: Create `When.pm`**

```perl
package Net::Nylas::Calendar::When;

use Moose;
with 'Net::Nylas::Calendar::ToJson';
use Kavorka qw( method multi );
use DateTime;
use DateTime::Format::ISO8601;

has $_, is => 'rw', clearer => "clear_$_"
    for qw( time timezone start_time end_time start_timezone end_timezone
            date start_date end_date );

method get () {
    if (defined $self->date) {
        my $dt = DateTime::Format::ISO8601->parse_datetime($self->date);
        return ($dt, $dt->clone, 1);
    }
    elsif (defined $self->start_date) {
        my $start = DateTime::Format::ISO8601->parse_datetime($self->start_date);
        my $end   = DateTime::Format::ISO8601->parse_datetime($self->end_date);
        return ($start, $end, 1);
    }
    elsif (defined $self->start_time) {
        my $start = DateTime->from_epoch( epoch => $self->start_time );
        my $end   = DateTime->from_epoch( epoch => $self->end_time   );
        eval { $start->set_time_zone($self->start_timezone) } if $self->start_timezone;
        eval { $end->set_time_zone($self->end_timezone)     } if $self->end_timezone;
        return ($start, $end, 0);
    }
    else {
        my $dt = DateTime->from_epoch( epoch => $self->time );
        eval { $dt->set_time_zone($self->timezone) } if $self->timezone;
        return ($dt, $dt->clone, 0);
    }
}

method set (DateTime $start, DateTime $end, $is_all_day) {
    # clear everything first
    $self->clear_time;         $self->clear_timezone;
    $self->clear_start_time;   $self->clear_end_time;
    $self->clear_start_timezone; $self->clear_end_timezone;
    $self->clear_date;
    $self->clear_start_date;   $self->clear_end_date;

    if ($is_all_day) {
        if ($start->ymd eq $end->ymd) {
            $self->date($start->ymd);
        } else {
            $self->start_date($start->ymd);
            $self->end_date($end->ymd);
        }
    } else {
        if ($start->epoch == $end->epoch) {
            $self->time($start->epoch);
            $self->timezone($start->time_zone->name)
                if $start->time_zone && !$start->time_zone->is_floating;
        } else {
            $self->start_time($start->epoch);
            $self->end_time($end->epoch);
            $self->start_timezone($start->time_zone->name)
                if $start->time_zone && !$start->time_zone->is_floating;
            $self->end_timezone($end->time_zone->name)
                if $end->time_zone && !$end->time_zone->is_floating;
        }
    }
}

1;
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add When model with get/set and DateTime conversion"
```

---

### Task 5: `Calendar` model

**Files:**
- Create: `lib/Net/Nylas/Calendar/Calendar.pm`

- [ ] **Step 1: Create `Calendar.pm`**

```perl
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

1;
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add Calendar model"
```

---

### Task 6: `Types` library

**Files:**
- Create: `lib/Net/Nylas/Calendar/Types.pm`

- [ ] **Step 1: Create `Types.pm`**

```perl
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
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add Types library"
```

---

### Task 7: `Event` model

**Files:**
- Create: `lib/Net/Nylas/Calendar/Event.pm`

- [ ] **Step 1: Create `Event.pm`**

```perl
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

has [ qw( title description location recurrence ) ], is => 'rw';
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

1;
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add Event model"
```

---

### Task 8: `Net::Nylas` base module

**Files:**
- Create: `lib/Net/Nylas.pm`

- [ ] **Step 1: Create `Net/Nylas.pm`**

```perl
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

1;
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add Net::Nylas base module"
```

---

### Task 9: `Net::Nylas::Calendar` main module

**Files:**
- Create: `lib/Net/Nylas/Calendar.pm`

- [ ] **Step 1: Create `Net/Nylas/Calendar.pm`**

```perl
package Net::Nylas::Calendar;

=head1 NAME

Net::Nylas::Calendar - Access Nylas Calendars using the v3 API

=cut

use Moose;
extends 'Net::Nylas';
use Kavorka;
use Types::Standard qw( ArrayRef );
use Net::Nylas::Calendar::Types qw( NylasCalendar CalendarId Event to_Event to_NylasCalendar );
use Net::Nylas::Calendar::Calendar;
use Net::Nylas::Calendar::Event;

has _current_calendar => is => 'rw', isa => CalendarId, coerce => 1;

method set_calendar ($cal) {
    $self->_current_calendar($cal);
}

method get_calendars {
    my $res = $self->_service->get('/calendars');
    die $res->error unless $res->success;
    map { to_NylasCalendar($_) } @{ $res->res->{data} };
}

method get_calendar ($id) {
    my $res = $self->_service->get('/calendars/[% id %]', { -id => $id });
    die $res->error unless $res->success;
    to_NylasCalendar($res->res->{data});
}

method get_events (%filters) {
    die "No calendar selected" unless $self->_current_calendar;
    my @items;
    my $cursor;
    do {
        my $params = { calendar_id => $self->_current_calendar, %filters };
        $params->{page_token} = $cursor if $cursor;
        my $res = $self->_service->get('/events', $params);
        die $res->error unless $res->success;
        push @items, @{ $res->res->{data} };
        $cursor = $res->res->{next_cursor};
    } while ($cursor);
    map { to_Event($_) } @items;
}

method get_event ($id) {
    die "No calendar selected" unless $self->_current_calendar;
    my $res = $self->_service->get('/events/[% id %]',
        { -id => $id, calendar_id => $self->_current_calendar });
    die $res->error unless $res->success;
    to_Event($res->res->{data});
}

method create_event ($event) {
    die "No calendar selected" unless $self->_current_calendar;
    $event->{-calendar_id} = $self->_current_calendar;
    my $res = $self->_service->post('/events?calendar_id=[% calendar_id %]', $event);
    die $res->error unless $res->success;
    to_Event($res->res->{data});
}

method update_event ($event) {
    die "No calendar selected" unless $self->_current_calendar;
    $event->{-id}          = $event->id;
    $event->{-calendar_id} = $self->_current_calendar;
    my $res = $self->_service->put('/events/[% id %]?calendar_id=[% calendar_id %]', $event);
    die $res->error unless $res->success;
    to_Event($res->res->{data});
}

method delete_event ($id) {
    die "No calendar selected" unless $self->_current_calendar;
    my $res = $self->_service->delete('/events/[% id %]?calendar_id=[% calendar_id %]',
        { -id => $id, -calendar_id => $self->_current_calendar });
    die $res->error unless $res->success || $res->code eq '404';
    1;
}

1;
```

- [ ] **Step 2: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git add lib/
git commit -m "Add Net::Nylas::Calendar main module"
```

---

### Task 10: Verify the module loads

There are no automated tests in this module (matching the Google module). Verify by loading all modules with `perl -I lib -e`.

- [ ] **Step 1: Check all modules compile**

```bash
cd ~/devel/cpan/net-nylas-calendar
perl -I lib -e '
    use Net::Nylas::Calendar::ToJson;
    use Net::Nylas::Calendar::Types;
    use Net::Nylas::Calendar::Organizer;
    use Net::Nylas::Calendar::Participant;
    use Net::Nylas::Calendar::When;
    use Net::Nylas::Calendar::Calendar;
    use Net::Nylas::Calendar::Event;
    use Net::Nylas;
    use Net::Nylas::Calendar;
    print "All modules loaded OK\n";
'
```

Expected output: `All modules loaded OK`

- [ ] **Step 2: Smoke-test object construction**

```bash
cd ~/devel/cpan/net-nylas-calendar
perl -I lib -e '
    use Net::Nylas::Calendar;
    use Net::Nylas::Calendar::Event;
    use Net::Nylas::Calendar::When;

    # construct a When from a hashref (coercion)
    use Net::Nylas::Calendar::Types qw(to_When);
    my $when = to_When({ start_time => 1700000000, end_time => 1700003600,
                         start_timezone => "America/New_York" });
    my ($s, $e, $allday) = $when->get;
    print "start: ", $s->datetime, "\n";
    print "end:   ", $e->datetime, "\n";
    print "allday: $allday\n";

    # round-trip set/get
    use DateTime;
    my $dt1 = DateTime->new(year=>2025, month=>6, day=>1, time_zone=>"UTC");
    my $dt2 = $dt1->clone->add(hours => 1);
    $when->set($dt1, $dt2, 0);
    my ($s2, $e2, $ad2) = $when->get;
    print "after set - start: ", $s2->datetime, " allday: $ad2\n";

    print "OK\n";
'
```

Expected output (timestamps will match the epoch):
```
start: 2023-11-14T...
end:   2023-11-14T...
allday: 0
after set - start: 2025-06-01T00:00:00 allday: 0
OK
```

- [ ] **Step 3: Commit**

```bash
cd ~/devel/cpan/net-nylas-calendar
git commit --allow-empty -m "Verified all modules load and When round-trips correctly"
```
