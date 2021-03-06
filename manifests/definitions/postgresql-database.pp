/*

==Definition: postgresql::database

Create a new PostgreSQL database

*/
define postgresql::database(
  $ensure=present,
  $owner=false,
  $encoding=false,
  $template="template1",
  $source=false,
  $compression="gzip",
  $overwrite=false) {

  $ownerstring = $owner ? {
    false => "",
    default => "-O $owner"
  }

  $encodingstring = $encoding ? {
    false => "",
    default => "-E $encoding",
  }

  $decompress = $compression ? {
    "raw" => "cat",
    "gzip" => "zcat",
    "bzip2" => "bzcat"
  }

  case $ensure {
    present: {
      exec { "Create $name postgres db":
        command => "/usr/bin/createdb $ownerstring $encodingstring $name -T $template",
        user => "postgres",
        unless => "/usr/bin/psql -U postgres -l | grep '$name  *|'",
        require => Service["postgresql"],
      }
    }
    absent:  {
      exec { "Remove $name postgres db":
        command => "/usr/bin/dropdb $name",
        onlyif => "/usr/bin/psql -U postgres -l | grep '$name  *|'",
        user => "postgres",
        require => Service["postgresql"],
      }
    }
    default: {
      fail "Invalid 'ensure' value '$ensure' for postgres::database"
    }
  }

  # Drop database before import
  if $overwrite {
    exec { "Drop database $name before import":
      command => "dropdb ${name}",
      onlyif => "/usr/bin/psql -U postgres -l | grep '$name  *|'",
      user => "postgres",
      before => Exec["Create $name postgres db"],
      require => Service["postgresql"],
    }
  }

  # Import initial dump
  if $source {
    exec { "Import dump into $name postgres db":
      command => "${decompress} ${source} | psql -U postgres ${name}",
      path => "/bin:/usr/bin",
      user => "postgres",
      onlyif => "test $(psql -U $owner ${name} -c '\\dt' | wc -l) -eq 1",
      require => Exec["Create $name postgres db"],
    }
  }
}
