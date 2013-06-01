package UAV::Pilot::Control::ARDrone::SDLNavOutput;
use v5.14;
use Moose;
use namespace::autoclean;
use File::Spec;
use SDL;
use SDLx::App;
use SDLx::Text;
use SDL::Event;
use SDL::Events;
use SDL::Video qw{ :surface :video };
use UAV::Pilot;

use constant {
    SDL_TITLE  => 'Nav Output',
    SDL_WIDTH  => 600,
    SDL_HEIGHT => 200,
    SDL_DEPTH  => 24,
    SDL_FLAGS  => SDL_HWSURFACE | SDL_HWACCEL | SDL_ANYFORMAT,
    BG_COLOR   => [ 0,   0,   0   ],
    DRAW_VALUE_COLOR        => [ 0x33, 0xff, 0x33 ],
    DRAW_CIRCLE_VALUE_COLOR => [ 0xa8, 0xa8, 0xa8 ],
    TEXT_LABEL_COLOR => [ 0,   0,   255 ],
    TEXT_VALUE_COLOR => [ 255, 0,   0   ],
    TEXT_SIZE  => 20,
    TEXT_FONT  => 'typeone.ttf',

    ROLL_LABEL_X      => 50,
    PITCH_LABEL_X     => 150,
    YAW_LABEL_X       => 250,
    ALTITUDE_LABEL_X  => 350,
    BATTERY_LABEL_X   => 450,

    ROLL_VALUE_X      => 50,
    PITCH_VALUE_X     => 150,
    YAW_VALUE_X       => 250,
    ALTITUDE_VALUE_X  => 350,
    BATTERY_VALUE_X   => 450,

    ROLL_DISPLAY_X      => 50,
    PITCH_DISPLAY_X     => 150,
    YAW_DISPLAY_X       => 250,
    ALTITUDE_DISPLAY_X  => 350,
    BATTERY_DISPLAY_X   => 450,

    LINE_VALUE_HALF_MAX_HEIGHT => 10,
    LINE_VALUE_HALF_LENGTH     => 40,

    CIRCLE_VALUE_RADIUS => 40,
};


has 'sdl' => (
    is  => 'ro',
    isa => 'SDLx::App',
);
has '_bg_color' => (
    is  => 'ro',
);
has '_bg_rect' => (
    is  => 'ro',
    isa => 'SDL::Rect',
);
has '_txt_label' => (
    is  => 'ro',
    isa => 'SDLx::Text',
);
has '_txt_value' => (
    is  => 'ro',
    isa => 'SDLx::Text',
);


sub BUILDARGS
{
    my ($class, $args) = @_;
    my @bg_color_parts = @{ $class->BG_COLOR };
    my @txt_color_parts = @{ $class->TEXT_LABEL_COLOR };
    my @txt_value_color_parts = @{ $class->TEXT_VALUE_COLOR };

    my $sdl = SDLx::App->new(
        title  => $class->SDL_TITLE,
        width  => $class->SDL_WIDTH,
        height => $class->SDL_HEIGHT,
        depth  => $class->SDL_DEPTH,
        flags  => $class->SDL_FLAGS,
    );
    $sdl->add_event_handler( sub {
        return 0 if $_[0]->type == SDL_QUIT;
        return 1;
    });

    my $bg_color = SDL::Video::map_RGB( $sdl->format, @bg_color_parts );
    my $bg_rect = SDL::Rect->new( 0, 0, $class->SDL_WIDTH, $class->SDL_HEIGHT );

    my $font_path = File::Spec->catfile(
        UAV::Pilot->default_module_dir,
        $class->TEXT_FONT,
    );
    my $label = SDLx::Text->new(
        font    => $font_path,
        color   => [ @txt_color_parts ],
        size    => $class->TEXT_SIZE,
        h_align => 'center',
    );
    my $value = SDLx::Text->new(
        font    => $font_path,
        color   => [ @txt_value_color_parts ],
        size    => $class->TEXT_SIZE,
        h_align => 'center',       
    );

    $$args{sdl}        = $sdl;
    $$args{_bg_color}  = $bg_color;
    $$args{_bg_rect}   = $bg_rect;
    $$args{_txt_label} = $label;
    $$args{_txt_value} = $value;
    return $args;
}


sub render
{
    my ($self, $nav) = @_;
    $self->_clear_screen;

    $self->_write_label( 'ROLL',     $self->ROLL_LABEL_X,     150 );
    $self->_write_label( 'PITCH',    $self->PITCH_LABEL_X,    150 );
    $self->_write_label( 'YAW',      $self->YAW_LABEL_X,      150 );
    $self->_write_label( 'ALTITUDE', $self->ALTITUDE_LABEL_X, 150 );
    $self->_write_label( 'BATTERY',  $self->BATTERY_LABEL_X,  150 );

    $self->_write_value_float_round( $nav->roll,     $self->ROLL_VALUE_X,     30 );
    $self->_write_value_float_round( $nav->pitch,    $self->PITCH_VALUE_X,    30 );
    $self->_write_value_float_round( $nav->yaw,      $self->YAW_VALUE_X,      30 );
    $self->_write_value( $nav->altitude . ' cm', $self->ALTITUDE_VALUE_X,     30 );
    $self->_write_value( $nav->battery_voltage_percentage . '%',
        $self->BATTERY_VALUE_X, 30 );

    $self->_draw_line_value(        $nav->roll,    $self->ROLL_DISPLAY_X,    100 );
    $self->_draw_line_value(        $nav->pitch,   $self->PITCH_DISPLAY_X,   100 );
    $self->_draw_circle_value(      $nav->yaw,     $self->YAW_DISPLAY_X,     100 );
    # Should we draw anything for altitude?
    $self->_draw_bar_percent_value( $nav->battery_voltage_percentage,
        $self->BATTERY_DISPLAY_X, 100 );

    SDL::Video::update_rects( $self->sdl, $self->_bg_rect );
    return 1;
}


sub _clear_screen
{
    my ($self) = @_;
    SDL::Video::fill_rect(
        $self->sdl,
        $self->_bg_rect,
        $self->_bg_color,
    );
    return 1;
}

sub _write_label
{
    my ($self, $text, $x, $y) = @_;
    my $txt = $self->_txt_label;
    my $app = $self->sdl;

    $txt->write_xy( $app, $x, $y, $text );

    return 1;
}

sub _write_value
{
    my ($self, $text, $x, $y) = @_;
    my $txt = $self->_txt_value;
    my $app = $self->sdl;

    $txt->write_xy( $app, $x, $y, $text );

    return 1;
}

sub _write_value_float_round
{
    my ($self, $text, $x, $y) = @_;
    my $txt = $self->_txt_value;
    my $app = $self->sdl;

    my $rounded = sprintf( '%.2f', $text );

    $txt->write_xy( $app, $x, $y, $rounded );

    return 1;
}

sub _draw_line_value
{
    my ($self, $value, $center_x, $center_y) = @_;
    my $app = $self->sdl;

    my $y_addition = int( $self->LINE_VALUE_HALF_MAX_HEIGHT * $value );
    my $right_y = $center_y - $y_addition;
    my $left_y  = $center_y + $y_addition;

    my $right_x = $center_x + $self->LINE_VALUE_HALF_LENGTH;
    my $left_x  = $center_x - $self->LINE_VALUE_HALF_LENGTH;

    $app->draw_line( [$left_x, $left_y], [$right_x, $right_y], $self->DRAW_VALUE_COLOR );
    return 1;
}

sub _draw_circle_value
{
    my ($self, $value, $center_x, $center_y) = @_;
    my $app = $self->sdl;
    my $radius = $self->CIRCLE_VALUE_RADIUS;
    my $color  = $self->DRAW_CIRCLE_VALUE_COLOR;

    # TODO calculate these
    my $line_x = 0;
    my $line_y = 0;

    $app->draw_circle( [$center_x, $center_y], $radius, $color );
    $app->draw_line( [$center_x, $center_y], [$center_x, $center_y - $radius], $color );

    #$app->draw_line( [$center_x, $center_y], [$line_x, $line_y], $self->DRAW_VALUE_COLOR );

    return 1;
}

sub _draw_bar_percent_value
{
    my ($self, $value, $center_x, $center_y) = @_;
    my $app = $self->sdl;

    # TODO
    return 1;
}


no Moose;
__PACKAGE__->meta->make_immutable;
1;
__END__

