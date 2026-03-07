var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Blue-Green Deployment Demo Working");

app.Run();
