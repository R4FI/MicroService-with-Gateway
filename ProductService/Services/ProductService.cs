using MongoDB.Driver;
using ProductService.Data;
using ProductService.Models;

namespace ProductService.Services;

public class ProductService
{
    private readonly MongoDbContext _context;

    public ProductService(MongoDbContext context)
    {
        _context = context;
    }

    public async Task<List<Product>> GetAllAsync()
    {
        return await _context.Products.Find(_ => true).ToListAsync();
    }

    public async Task<Product?> GetByIdAsync(string id)
    {
        return await _context.Products
            .Find(x => x.Id == id)
            .FirstOrDefaultAsync();
    }

    public async Task<Product> CreateAsync(Product product)
    {
        await _context.Products.InsertOneAsync(product);
        return product;
    }

    public async Task<bool> UpdateAsync(string id, Product updatedProduct)
    {
        var result = await _context.Products.ReplaceOneAsync(
            x => x.Id == id,
            updatedProduct
        );

        return result.ModifiedCount > 0;
    }
    public async Task<bool> DeleteAsync(string id)
    {
        var result = await _context.Products.DeleteOneAsync(x => x.Id == id);
        return result.DeletedCount > 0;
    }
}
