using Microsoft.AspNetCore.Mvc;
using ProductService.Models;
using ProductService.Services;

namespace ProductService.Controllers;

[ApiController]
[Route("api/products")]
public class ProductsController : ControllerBase
{
    private readonly Services.ProductService _service;

    public ProductsController(Services.ProductService service)
    {
        _service = service;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var products = await _service.GetAllAsync();
        return Ok(products);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id)
    {
        var product = await _service.GetByIdAsync(id);

        if (product == null)
            return NotFound("Product not found.");

        return Ok(product);
    }

    [HttpPost]
    public async Task<IActionResult> Create(Product product)
    {
        if (product.Price <= 0)
            return BadRequest("Product price must be greater than zero.");

        var createdProduct = await _service.CreateAsync(product);

        return Ok(createdProduct);
    }

    [HttpPut("{id}")]
    public async Task<IActionResult> Update(string id, Product product)
    {
        product.Id = id;

        var updated = await _service.UpdateAsync(id, product);

        if (!updated)
            return NotFound("Product not found.");

        return Ok(new { message = "Product updated successfully." });
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var deleted = await _service.DeleteAsync(id);

        if (!deleted)
            return NotFound("Product not found.");

        return Ok(new { message = "Product deleted successfully." });
    }
}
