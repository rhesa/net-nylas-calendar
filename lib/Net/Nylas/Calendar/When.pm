package Net::Nylas::Calendar::When;

use Moose;
with 'Net::Nylas::Calendar::ToJson';
use Kavorka;
use DateTime;
use DateTime::Format::ISO8601;

has $_, is => 'rw', clearer => "clear_$_"
    for qw( time timezone start_time end_time start_timezone end_timezone
            date start_date end_date );

method get () {
    die "When has no time fields set"
        unless defined($self->date)     || defined($self->start_date)
            || defined($self->start_time) || defined($self->time);

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

__PACKAGE__->meta->make_immutable;

1;
