package Net::Nylas::Calendar;

=head1 NAME

Net::Nylas::Calendar - Access Nylas Calendars using the v3 API

=cut

use Moose;
extends 'Net::Nylas';
use Kavorka;
use Types::Standard;
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
    my $params = { %filters, calendar_id => $self->_current_calendar };
    my $res = $self->_service->get('/events', $params);
    die $res->error unless $res->success;
    my @items = @{ $res->res->{data} };
    if (wantarray) {
        my $cursor = $res->res->{next_cursor};
        while ($cursor) {
            $params = { %filters, calendar_id => $self->_current_calendar, page_token => $cursor };
            $res = $self->_service->get('/events', $params);
            die $res->error unless $res->success;
            push @items, @{ $res->res->{data} };
            $cursor = $res->res->{next_cursor};
        }
        return map { to_Event($_) } @items;
    }
    return {
        events      => [ map { to_Event($_) } @items ],
        next_cursor => $res->res->{next_cursor},
    };
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
    my $params = { %$event, -calendar_id => $self->_current_calendar };
    my $res = $self->_service->post('/events?calendar_id=[% calendar_id %]', $params);
    die $res->error unless $res->success;
    to_Event($res->res->{data});
}

method update_event ($event) {
    die "No calendar selected" unless $self->_current_calendar;
    my $params = { %$event, -id => $event->{id}, -calendar_id => $self->_current_calendar };
    my $res = $self->_service->put('/events/[% id %]?calendar_id=[% calendar_id %]', $params);
    die $res->error unless $res->success;
    to_Event($res->res->{data});
}

method delete_event ($id) {
    die "No calendar selected" unless $self->_current_calendar;
    my $res = $self->_service->delete('/events/[% id %]?calendar_id=[% calendar_id %]',
        { -id => $id, -calendar_id => $self->_current_calendar });
    die $res->error unless $res->success || $res->code == 404;
    1;
}

__PACKAGE__->meta->make_immutable;

1;
