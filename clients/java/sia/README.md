Service Identity Agent Client Java Library

System properties:

  athenz.sia.client.ntoken_path
      When used in athenz enabled environment, this setting specifies
      the path of the file that contains the ntoken generated by the framework.
      This setting requires that ntoken_domain and ntoken_service settings
      to be configured as well.

  athenz.sia.client.ntoken_domain
      This setting specifies the domain name of the service that is identified
      by the ntoken generated by the framework(see ntoken_path above).
      This setting requires that ntoken_path and ntoken_service settings
      to be configured as well.

  athenz.sia.client.ntoken_service
      This setting specifies the service name that is identified
      by the ntoken generated by the framework(see ntoken_path above).
      This setting requires that ntoken_path and ntoken_domain settings
      to be configured as well.

## License

Copyright 2016 Yahoo Inc.

Licensed under the Apache License, Version 2.0: [http://www.apache.org/licenses/LICENSE-2.0]()