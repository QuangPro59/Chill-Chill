extends Node

var money := 500
var season_index := 0
var day := 1
var touched := false

func save_from_farm(farm_money: int, farm_season: int) -> void:
	money = farm_money
	season_index = clampi(farm_season - 1, 0, 3)
	day = 1
	touched = true

func save_from_meadow(meadow_money: int, meadow_season: int, meadow_day: int) -> void:
	money = meadow_money
	season_index = clampi(meadow_season, 0, 3)
	day = clampi(meadow_day, 1, 7)
	touched = true
