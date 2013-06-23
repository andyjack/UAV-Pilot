use Test::More tests => 4;
use v5.14;
use UAV::Pilot;
use UAV::Pilot::Driver::ARDrone::Mock;
use UAV::Pilot::Driver::ARDrone::Video::Mock;
use UAV::Pilot::Control::ARDrone::Video::FileDump;
use File::Temp ();
use AnyEvent;
use Test::Moose;

use constant VIDEO_DUMP_FILE         => 't_data/ardrone_video_stream_dump.bin';
use constant MAX_WAIT_TIME           => 5;
use constant EXPECT_FRAMES_PROCESSED => 25;

# The smaller size is output by the module code, while the large size is output by the 
# standalone scripts/video_dump.pl code.  Why the difference?
#
#use constant EXPECT_SIZE     => 102_274;
use constant EXPECT_SIZE     => 98_304;

my ($OUTPUT_FH, $OUTPUT_FILE) = File::Temp::tempfile( 'ardrone_video_stream.h264.XXXXXX',
    UNLINK => 1,
);


my $control_video = UAV::Pilot::Control::ARDrone::Video::FileDump->new({
    fh => $OUTPUT_FH,
});
does_ok( $control_video => 'UAV::Pilot::Driver::ARDrone::VideoHandler' );

my $cv = AnyEvent->condvar;
my $ardrone = UAV::Pilot::Driver::ARDrone::Mock->new({
    host => '192.168.1.1',
});
my $driver_video = UAV::Pilot::Driver::ARDrone::Video::Mock->new({
    file    => VIDEO_DUMP_FILE,
    handler => $control_video,
    condvar => $cv,
    driver  => $ardrone,
});
isa_ok( $driver_video => 'UAV::Pilot::Driver::ARDrone::Video' );


my $pass_timer; $pass_timer = AnyEvent->timer(
    after    => 1,
    interval => 0.1,
    cb       => sub {
        my $pass = (EXPECT_SIZE == -s $OUTPUT_FILE);
        if( EXPECT_SIZE == -s $OUTPUT_FILE ) {
            pass( 'File '
                . $OUTPUT_FILE
                . ' matches expected size '
                . EXPECT_SIZE );
            $cv->send( 'Pass' );
        }
        $pass_timer;
    },
);
my $timeout_timer; $timeout_timer = AnyEvent->timer(
    after => MAX_WAIT_TIME,
    cb    => sub {
        fail( 'File '
            . $OUTPUT_FILE
            . ' did not match expected size '
            . EXPECT_SIZE
            . ' after '
            . MAX_WAIT_TIME
            . ' seconds.'
            . '  Actual size is '
            . (-s $OUTPUT_FILE)
            . '.' );
        $cv->send( 'Failed' );
        $timeout_timer;
    },
);


$driver_video->init_event_loop;
$cv->recv;

cmp_ok( $driver_video->frames_processed, '==', EXPECT_FRAMES_PROCESSED,
    'Expected number of frames processed' );

close $OUTPUT_FH;
