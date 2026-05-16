using Plots

# Sample Data
x = 1:10
y1 = rand(10)  # Random values
y2 = rand(10)

# Creating the Plot
plt = plot(x, y1,
    label="Line 1",           # Label for the first line
    linestyle=:dashdot,       # Line style (:solid, :dash, :dot, :dashdot)
    linewidth=3,              # Thickness of the line
    color=:blue,              # Line color (e.g., :red, :green, :blue)
    marker=:circle,           # Marker shape (:circle, :square, :diamond, :star)
    markersize=8,             # Size of markers
    markercolor=:black,       # Color of markers
    grid=true,                # Enable grid (default)
    gridstyle=:dot,           # Grid style (:solid, :dash, :dot, :dashdot)
    framestyle=:box,          # Frame style (:box, :semi, :none)
    background_color=:lightgray,  # Background color
    legend=:topright,         # Legend position
    xlabel="X-axis Label",    # X-axis label
    ylabel="Y-axis Label",    # Y-axis label
    title="Customized Plot",  # Title of the plot
    dpi=300                   # High-resolution plot
)

# Adding another line with different settings
plot!(x, y2,
    label="Line 2",
    linestyle=:solid,
    color=:red,
    linewidth=2,
    markershape=:square
)

# Saving the figure
savefig(plt, "custom_plot.png")  # Save as PNG file
display(plt)  # Show the plot
