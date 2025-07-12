local database = peripheral.wrap('right')

database.prepareStatement(
   "CREATE TABLE IF NOT EXISTS friends ("..
   "id INTEGER PRIMARY KEY AUTOINCREMENT,"..
   "name VARCHAR(40) NOT NULL,"..
   "price INTEGER"..
")").execute();

insertProductStatement = database.prepareStatement(
    "INSERT INTO friends VALUES(NULL, ?, ?)"
);

paramName = 1;
paramPrice = 2;

insertProductStatement
   .setParameter(paramName, 'johanna')
   .setParameter(paramPrice, 12)
   .execute();
insertProductStatement
   .setParameter(paramName, 'hiasi')
   .setParameter(paramPrice, 10)
   .execute();
   
queryByName = database.prepareStatement(
    "SELECT * FROM friends WHERE name LIKE ?"
);

paramName = 1;
result = queryByName
   .setParameter(paramName, '%hia%')
   .execute();

for i,row in pairs(result.data) do
   print(('%i: %s %i'):format(i, row.name, row.price));
    end
