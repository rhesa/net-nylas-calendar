# Net::Nylas::Calendar Design

**Date:** 2026-04-07  
**Status:** Approved

## Overview

A standalone CPAN-publishable Perl wrapper for the Nylas Calendar API v3. Modelled closely after `Net::Google::CalendarV3` but exposing the Nylas API natively (Nylas field names and semantics). Uses Moose, Kavorka, and Types::Standard throughout.

Intended to be vendored into suitesetup later; the BO layer will handle translation between Nylas field names and internal app conventions.

## Module Namespace

`Net::Nylas` — base namespace for auth/HTTP plumbing, extensible to future Nylas API resources (Contacts, Threads, etc.).

`Net::Nylas::Calendar` — calendar-specific resource wrapper, extends `Net::Nylas`.

## Authentication

Two supported modes, mutually exclusive:

- **API key**: set `api_key`; used as Bearer token
- **OAuth access token**: set `oauth_access_token`; used as Bearer token

Both require `grant_id`, which is interpolated into the base URL at service build time:

```
https://api.us.nylas.com/v3/grants/{grant_id}
```

Auth header is built lazily the same way as the Google module:

```perl
sub { $_[1]->header(Authorization => "Bearer $token") }
```

## Module List

### `Net::Nylas`

Base module. Attributes:

| attribute | notes |
|---|---|
| `api_key` | ro, predicate `has_api_key` |
| `oauth_access_token` | ro, predicate `has_token` |
| `grant_id` | ro, required |
| `_service` | ro, lazy, WWW::JSON instance |
| `authentication` | ro, lazy, built from whichever credential is present |

Dies during `_build_authentication` if neither `api_key` nor `oauth_access_token` is provided.

### `Net::Nylas::Calendar`

Extends `Net::Nylas`. Additional attributes:

| attribute | notes |
|---|---|
| `_current_calendar` | rw, isa CalendarId, coerce from Calendar object or Str |

Methods:

| method | HTTP | notes |
|---|---|---|
| `get_calendars` | GET /calendars | returns list of Calendar objects |
| `get_calendar($id)` | GET /calendars/{id} | returns single Calendar |
| `set_calendar($cal)` | — | sets `_current_calendar` |
| `get_events(%filters)` | GET /events?calendar_id=... | auto-paginated via `next_cursor` |
| `get_event($id)` | GET /events/{id}?calendar_id=... | returns single Event |
| `create_event($event)` | POST /events?calendar_id=... | returns created Event |
| `update_event($event)` | PUT /events/{id}?calendar_id=... | returns updated Event |
| `delete_event($id)` | DELETE /events/{id}?calendar_id=... | returns 1 on success |

All event methods require `_current_calendar` to be set (die if not).

Pagination: loop on `next_cursor` in response, passing it as `page_token` query param on subsequent requests.

API responses are wrapped: `{ request_id: ..., data: ..., next_cursor: ... }`. We read `$res->res->{data}`.

### `Net::Nylas::Calendar::Calendar`

Moose class. Attributes (all `ro`):

`id`, `grant_id`, `name`, `description`, `location`, `timezone`, `read_only`, `is_primary`, `object`, `hex_color`, `hex_foreground_color`

### `Net::Nylas::Calendar::Event`

Moose class, `with 'Net::Nylas::Calendar::ToJson'`. Attributes:

| attribute | rw/ro | type/notes |
|---|---|---|
| `id` | ro | Str |
| `grant_id` | ro | Str |
| `calendar_id` | ro | Str |
| `ical_uid` | ro | Str |
| `html_link` | ro | Str |
| `created_at` | ro | Int (Unix timestamp) |
| `updated_at` | ro | Int (Unix timestamp) |
| `object` | ro | Str |
| `title` | rw | Str |
| `description` | rw | Str |
| `location` | rw | Str |
| `when` | rw | When, coerce from HashRef |
| `status` | rw | Enum[qw(confirmed tentative cancelled)] |
| `busy` | rw | CBool, coerce |
| `visibility` | rw | Enum[qw(public private)] |
| `participants` | rw | ArrayRef[Participant], coerce, default [] |
| `recurrence` | rw | ArrayRef[Str] |
| `organizer` | rw | Organizer, coerce from HashRef |
| `reminders` | rw | HashRef |
| `metadata` | rw | HashRef |

### `Net::Nylas::Calendar::When`

Moose class, `with 'Net::Nylas::Calendar::ToJson'`. Handles all four Nylas `when` subtypes by detecting which fields are present:

| subtype | fields present |
|---|---|
| `time` | `time` (+ optional `timezone`) |
| `timespan` | `start_time`, `end_time` (+ optional `start_timezone`, `end_timezone`) |
| `date` | `date` |
| `datespan` | `start_date`, `end_date` |

Attributes: `time`, `timezone`, `start_time`, `end_time`, `start_timezone`, `end_timezone`, `date`, `start_date`, `end_date` — all `rw` with clearers.

**`get()`** — returns `($start_dt, $end_dt, $is_all_day)`:
- `time`: start = end = DateTime from Unix timestamp; `$is_all_day = 0`
- `timespan`: start/end from Unix timestamps, apply timezones if present; `$is_all_day = 0`
- `date`: start = end = DateTime from date string (floating); `$is_all_day = 1`
- `datespan`: start/end from date strings (floating); `$is_all_day = 1`

**`set($start_dt, $end_dt, $is_all_day)`** — writes the appropriate subtype:
- `$is_all_day && $start == $end`: writes `date`
- `$is_all_day && $start != $end`: writes `datespan`
- `!$is_all_day && $start == $end`: writes `time` (+ timezone if not floating)
- `!$is_all_day && $start != $end`: writes `timespan` (+ timezones if not floating)

Clears all other fields before writing.

### `Net::Nylas::Calendar::Participant`

Moose class, `with 'Net::Nylas::Calendar::ToJson'`. Attributes (`ro`):

`email`, `name`, `status` (Enum[qw(yes no maybe noreply)]), `comment`, `phone_number`

### `Net::Nylas::Calendar::Organizer`

Moose class, `with 'Net::Nylas::Calendar::ToJson'`. Attributes (`ro`): `email`, `name`

### `Net::Nylas::Calendar::Types`

`Type::Library`. Declares and coerces:

| type | class | coerce from |
|---|---|---|
| `NylasCalendar` | `::Calendar` | HashRef |
| `Event` | `::Event` | HashRef |
| `When` | `::When` | HashRef |
| `Participant` | `::Participant` | HashRef |
| `Organizer` | `::Organizer` | HashRef |
| `CalendarId` | — | Str or NylasCalendar (via `->id`) |
| `CBool` | — | Any (via `!!`) |

### `Net::Nylas::Calendar::ToJson`

Moose role. Single method: `TO_JSON { %$self }`.

## Error Handling

Same pattern as `Net::Google::CalendarV3`: `die $res->error unless $res->success`. Callers wrap in `try/catch`. `delete_event` additionally tolerates 404.

## Distribution

- `dist.ini` (Dist::Zilla), mirroring the structure in `net-google-calendar`
- Standalone repo at `~/devel/cpan/net-nylas-calendar`
- No test suite in initial build (matching the Google module)
