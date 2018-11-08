# Wallaroo Roadmap

Please note that this document is meant to provide high-level visibility into the work we have planned for Wallaroo. The roadmap can change at any time. Work is prioritized in part by the needs our clients and partners. If you are interested in working with us, please contact us at [hello@wallaroolabs.com](mailto:hello@wallaroolabs.com)

## Effectively-once message processing

Effectively-once message processing is the holy grail of data processing. You should get the same correct results from a system that encountered failures while processing as one that ran without issue. 

Additional support is needed when interfacing with external systems. To complete this work, Wallaroo needs:

- To support message replay from external sources
- An acknowledgment and transaction protocol with external sink to prevent duplicate output messages
