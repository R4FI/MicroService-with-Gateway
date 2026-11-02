using ProductService.Data;
using ProductService.Models;
using ProductService.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.Configure<MongoDbSettings>(
    builder.Configuration.GetSection("MongoDbSettings")
);

builder.Services.AddSingleton<MongoDbContext>();
builder.Services.AddSingleton<ProductService.Services.ProductService>();

builder.Services.AddCors(options =>
{
options.AddPolicy("AllowAll", policy =>
{
    policy.AllowAnyOrigin()
                 .AllowAnyHeader()
                 .AllowAnyMethod();
});
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

app.UseCors("AllowAll");

app.UseSwagger();
app.UseSwaggerUI();

app.MapControllers();

app.Run();
