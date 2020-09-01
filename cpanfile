use strict;
use warnings;

requires "Encode"           => 0;
requires "HTTP::Tiny"       => "0.076";
requires "JSON::XS"         => 0;
requires "Simple::Accessor" => 0;

on 'test' => sub {
    requires "ExtUtils::MakeMaker"       => 0;
    requires "File::Spec"                => 0;
    requires "File::Temp"                => 0;
    requires "Test2::Bundle::Extended"   => 0;
    requires "Test2::Plugin::NoWarnings" => 0;
    requires "Test2::Tools::Explain"     => 0;
    requires "Test::MockModule"          => "0.13";
    requires "Test::More"                => 0;
};
