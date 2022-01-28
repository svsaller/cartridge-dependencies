//delete all
match (n) detach delete n

//load cartridge dependencies
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/svsaller/cartridge-dependencies/develop/import/deps.csv' AS row
MERGE (c:Cartridge {name: row.cartridge})
WITH c, row
UNWIND split(row.dependencies, ':') AS dep
MERGE (d:Cartridge {name: dep})
MERGE (c)-[r:DEPENDS_ON]->(d)

//load app-cartridge assignments
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/svsaller/cartridge-dependencies/develop/import/apps.csv' AS row
MERGE (app:App {name: row.application})
WITH app, row
UNWIND split(row.dependencies, ':') AS assignment
MERGE (cartridge:Cartridge {name: assignment})
WITH app, cartridge, row
MERGE (app)-[:DEPENDS_ON {assigner: row.assigner, isOptional: row.isOptional, isExtension: row.isExtension}]->(cartridge)

//load app-subprovider dependencies
LOAD CSV WITH HEADERS FROM 'https://raw.githubusercontent.com/svsaller/cartridge-dependencies/develop/import/apps-sub.csv' AS row
MERGE (app:App {name: row.application})
MERGE (dep:App {name: row.dependency})
WITH app, dep, row
MERGE (app)-[:DEPENDS_ON {assigner: row.assigner, isSubprovider: 'true'}]->(dep)