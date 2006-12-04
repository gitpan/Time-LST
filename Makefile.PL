use 5.008008;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'Time::LST',
    VERSION_FROM      => 'lib/Time/LST.pm', 
    PREREQ_PM         => { Astro::Time => 0}, 
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Time/LST.pm', 
       AUTHOR         => 'Roderick Garton <rgarton@utas_._edu_._au>') : ()),
);
