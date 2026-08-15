local _, ns = ...

-- enUS is the fallback: any key missing from a translation falls back to this table.
local L = {
	USED_IN_LURES   = "Used in Skinning lures:",
	REAGENTS        = "Lure reagents:",
	YOU_HAVE        = "you have %d",
	PER_CRAFT       = "%d per craft",
	CRAFTABLE       = "%d craftable",
	CAN_CRAFT       = "can craft %d",
	SHORT_OF        = "short %d %s",
	HAVE_OF_NEED    = "%d / %d",

	OPT_TITLE       = "Lures Reagents",
	OPT_ENABLED     = "Enable tooltips",
	OPT_ENABLED_TT  = "Turn all tooltip additions from this addon on or off.",
	OPT_ON_REAGENTS = "Annotate reagent tooltips",
	OPT_ON_REAGENTS_TT = "On a fish that is a lure reagent, list the lures it is used for.",
	OPT_ON_LURES    = "Annotate lure tooltips",
	OPT_ON_LURES_TT = "On a Majestic Beast Lure, list the fish it requires.",
	OPT_COUNTS      = "Show how many you own",
	OPT_COUNTS_TT   = "Include the amount currently in your bags and banks.",
	OPT_CRAFTABLE   = "Show how many you can craft",
	OPT_CRAFTABLE_TT= "Take every reagent of the recipe into account, not just the one hovered.",
	OPT_SHORT       = "Show what you are short of",
	OPT_SHORT_TT    = "When another reagent is the limiting one, name it and the missing amount.",
	OPT_BANK        = "Count bank and reagent bank",
	OPT_BANK_TT     = "Include items stored in your bank and reagent bank.",
	OPT_WARBAND     = "Count warband bank",
	OPT_WARBAND_TT  = "Include items stored in the account-wide warband bank.",

	SLASH_HEADER    = "Lures Reagents — options (/lr <option> to toggle):",
	SLASH_CONFIG    = "|cffffd100/lr config|r — open the settings panel",
	SLASH_UNKNOWN   = "Unknown option '%s'. Type /lr for the list.",
	SLASH_ON        = "|cff20ff20on|r",
	SLASH_OFF       = "|cffff2020off|r",
}

local translations = {
	frFR = {
		USED_IN_LURES   = "Utilisé pour les appâts de Dépeçage :",
		REAGENTS        = "Composants de l'appât :",
		YOU_HAVE        = "vous en avez %d",
		PER_CRAFT       = "%d par fabrication",
		CRAFTABLE       = "%d fabricable(s)",
		CAN_CRAFT       = "%d fabricable(s)",
		SHORT_OF        = "il manque %d %s",
		HAVE_OF_NEED    = "%d / %d",

		OPT_TITLE       = "Lures Reagents",
		OPT_ENABLED     = "Activer les infobulles",
		OPT_ENABLED_TT  = "Active ou désactive tous les ajouts d'infobulle de cet addon.",
		OPT_ON_REAGENTS = "Annoter les composants",
		OPT_ON_REAGENTS_TT = "Sur un poisson servant de composant, lister les appâts concernés.",
		OPT_ON_LURES    = "Annoter les appâts",
		OPT_ON_LURES_TT = "Sur un appât de bête majestueuse, lister les poissons nécessaires.",
		OPT_COUNTS      = "Afficher vos quantités",
		OPT_COUNTS_TT   = "Inclure ce que vous avez actuellement en sacs et en banques.",
		OPT_CRAFTABLE   = "Afficher le nombre fabricable",
		OPT_CRAFTABLE_TT= "Tenir compte de tous les composants de la recette, pas seulement celui survolé.",
		OPT_SHORT       = "Afficher ce qui vous manque",
		OPT_SHORT_TT    = "Quand un autre composant est le facteur limitant, le nommer avec la quantité manquante.",
		OPT_BANK        = "Compter banque et banque de composants",
		OPT_BANK_TT     = "Inclure les objets rangés en banque et en banque de composants.",
		OPT_WARBAND     = "Compter la banque de bataillon",
		OPT_WARBAND_TT  = "Inclure les objets rangés dans la banque de bataillon, commune au compte.",

		SLASH_HEADER    = "Lures Reagents — options (/lr <option> pour basculer) :",
		SLASH_CONFIG    = "|cffffd100/lr config|r — ouvrir le panneau de configuration",
		SLASH_UNKNOWN   = "Option « %s » inconnue. Tapez /lr pour la liste.",
		SLASH_ON        = "|cff20ff20activé|r",
		SLASH_OFF       = "|cffff2020désactivé|r",
	},
}

local locale = translations[GetLocale()]
if locale then
	for key, value in pairs(locale) do
		L[key] = value
	end
end

ns.L = L
