#!/usr/bin/env nu

export def main [] {
  help commands main
}

# Returns PWD from root directory
export def project-root [] {
  let ls = (ls -a | where name == ".git");
  if (($ls | length) == 0) {
    (cd ..);
    let current_path = (pwd);
    if ($current_path == "/") {
      error make {msg: "Got to filesystem root without encountering .git"};
    }
    return (project-root);
  } else {
    return (pwd);
  }
}

export def `main dirhash` [...dirs: string] {
  print $dirs
}