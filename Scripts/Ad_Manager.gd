extends Node

# LINK FOR MORE ADMOB STUFF: https://godotengine.org/qa/52061/real-ads-implementation-tutorial

# THESE ARE OFFICIAL GOOGLE TEST IDS
# var adBannerId = "ca-app-pub-3940256099942544/6300978111" # [Replace with your Ad Unit ID and delete this message.]
# var adInterstitialId = "ca-app-pub-3940256099942544/1033173712"
# var adRewardedId = "ca-app-pub-3940256099942544/5224354917" # [There is no testing option for rewarded videos, so you can use this id for testing]

# APP ID: ca-app-pub-7465988806111884~3749512243

# THESE ARE THE REAL IDS
#var adBannerId = ... I will never use those anyway
var adInterstitialId = "TODO: ADD YOUR ID"
var adRewardedId = "TODO: ADD YOUR ID"

var interstitialLoaded = false
var rewarded_video_loaded = false
var was_rewarded = false

var admob = null


func _ready():
	admob = AdMob.new()
	
	var is_real = not OS.is_debug_build()
	var child_directed = true
	var is_personalized = false
	var max_ad_content_rate = "G"
	
	admob.is_real = is_real
	admob.child_directed = child_directed
	admob.is_personalized = is_personalized
	admob.max_ad_content_rate = max_ad_content_rate
	
	admob.interstitial_id = adInterstitialId
	admob.rewarded_id = adRewardedId
	
	admob.connect("rewarded_video_failed_to_load", self, "on_rewarded_video_failed_to_load")
	admob.connect("rewarded_video_loaded", self, "on_rewarded_video_loaded")
	admob.connect("rewarded_video_closed", self, "on_rewarded_video_closed")
	admob.connect("rewarded", self, "on_rewarded")
	
	get_tree().get_root().add_child(admob) 
	load_rewarded_video()

func active():
	return admob._admob_singleton != null

func rewarded_video_is_loaded() -> bool:
	return rewarded_video_loaded

###
# Loaders
###
	
func load_rewarded_video():
	if not active(): return
	admob.load_rewarded_video()

func show_rewarded_video():
	if not active(): return
	admob.show_rewarded_video()

func reload_rewarded_video():
	if not active(): return
	# if we don't have a rewarded video loaded, try again
	if not rewarded_video_loaded:
		load_rewarded_video()

func on_rewarded_video_failed_to_load(err):
	print("Rewarded video FAILED to load")
	print(str(err))

func on_rewarded_video_loaded():
	rewarded_video_loaded = true
	was_rewarded = false
	print("Rewarded loaded success")
	
func on_rewarded_video_closed():
	rewarded_video_loaded = false
	print("Rewarded closed")
	load_rewarded_video() # already load the next rewarded video
	
func on_rewarded(currency, amount):
	var root_node = get_node('/root/Node2D')
	root_node.just_watched_ad = true
	root_node.enable_game_after_ad()
	print("Rewarded!")
