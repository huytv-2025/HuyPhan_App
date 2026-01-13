using HuyPhanApi.Services;
var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddControllers()
        .AddJsonOptions(options =>
    {
        // Bật binding không phân biệt chữ hoa/thường (camelCase / PascalCase)
        options.JsonSerializerOptions.PropertyNameCaseInsensitive = true;

        // Tùy chọn: nếu muốn response trả về camelCase
        // options.JsonSerializerOptions.PropertyNamingPolicy = JsonNamingPolicy.CamelCase;
    });
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddSingleton<FcmService>();

// Bật CORS để Flutter và Swagger gọi được API
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();
var fcmService = app.Services.GetRequiredService<FcmService>();
app.UseStaticFiles();
// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Bật CORS
app.UseCors("AllowAll");

app.UseAuthorization();

app.MapControllers();

app.Run();