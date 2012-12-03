0.2.0
-----
* Add missing `#ctcp_type` and `#dcc_type` accessors
* Make `#type, `#ctcp_type`, and `#dcc_type` return symbols, not strings
* Rename `#numeric_name` to `#name`
* Remove superfluous `#numeric` and `#numeric_args` (use `#command` and `#args`)
* Depend on Ruby 1.9.2 and use Float::INFINITY for some ISupport defaults

0.1.0
-----
* Initial release
