import rio
import os
import sys

class TestApp(rio.Component):
    def build(self) -> rio.Component:
        return rio.Column(
            rio.Icon(icon="material/home"),
            rio.Text("Testing theme and icon", style=rio.TextStyle(font_size=2.0, font_weight="bold"))
        )

theme = rio.Theme.from_colors(
    mode="dark",
    primary_color=rio.Color.from_hex("#1F6FEB"),
    background_color=rio.Color.from_hex("#0D1117")
)

app = rio.App(name="Test Theme", build=TestApp, theme=theme)
print("Theme instantiated without error.")
