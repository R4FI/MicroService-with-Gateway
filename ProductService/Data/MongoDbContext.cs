using Microsoft.Extensions.Options;
using MongoDB.Driver;
using ProductService.Models;

namespace ProductService.Data;

public class MongoDbContext
{
    private readonly IMongoDatabase _database;
    private readonly MongoDbSettings _settings;

    public MongoDbContext(IOptions<MongoDbSettings> settings)
    {
        _settings = settings.Value;

        var client = new MongoClient(_settings.ConnectionString);

        _database = client.GetDatabase(_settings.DatabaseName);
    }

    public IMongoCollection<Product> Products =>
        _database.GetCollection<Product>(_settings.ProductsCollectionName);
}
