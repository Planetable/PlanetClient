# Persistence

Right now, we are using good ol' JSON to store what we've obtained from the Planet API. Here is the on-disk structure for those files:

* Each Planet instance has its own node ID, which is the IPFS peer ID like this: 12D3KooWNFiZC58awi61jA2exk7sA1TMS4LNCduQmd3FwD1ZUnq5. It can be fetched from `/v0/id`.
* Root for each instance: `Documents/:node_id`
* Root for each My Planet: `Documents/:node_id/My/:planet_id`
* Planet info file: `Documents/:node_id/My/:planet_id/planet.json`
* Articles: `Documents/:node_id/My/:planet_id/articles.json`

While the published Planet site contains a `planet.json` that includes both information and articles, we've split them into two separate files here so that they can be updated independently.
