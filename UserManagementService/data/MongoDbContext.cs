using System;
using Microsoft.Extensions.Options;
using MongoDB.Driver;
using UserManagementService.Models;

namespace UserManagementService.Data;

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
    public IMongoCollection<User> Users =>
    _database.GetCollection<User>(_settings.UsersCollectionName);
}