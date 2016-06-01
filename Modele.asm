;;===========================================================================;;
;;= MODÈLE DE PROGRAMME ASSEMBLEUR 6502 POUR NINTENDO ENTERTAINEMENT SYSTEM =;;
;;======================= Produit par François Allard =======================;;
;;====================== Cégep de Drummondville - 2014 ======================;;
;;===========================================================================;;
;;
;; $0000-0800 - Mémoire vive interne, puce de 2KB dans la NES
;; $2000-2007 - Ports d'accès du PPU
;; $4000-4017 - Ports d'accès de l'APU
;; $6000-7FFF - WRAM optionnelle dans la ROM
;; $8000-FFFF - ROM du programme
;;
;; Contrôle du PPU ($2000)
;; 76543210
;; ||||||||
;; ||||||++- Adresse de base de la table de noms
;; ||||||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
;; ||||||
;; |||||+--- Incrément de l'adresse en VRAM à chaque écriture du CPU
;; |||||     (0: incrément par 1; 1: incrément par 32 (ou -1))
;; |||||
;; ||||+---- Adresse pour les motifs de sprites (0: $0000; 1: $1000)
;; ||||
;; |||+----- Adresse pour les motifs de tuiles (0: $0000; 1: $1000)
;; |||
;; ||+------ Taille des sprites (0: 8x8; 1: 8x16)
;; ||
;; |+------- Inutilisé
;; |
;; +-------- Générer un NMI à chaque VBlank (0: off; 1: on)
;;
;; Masque du PPU ($2001)
;; 76543210
;; ||||||||
;; |||||||+- Nuances de gris (0: couleur normale; 1: couleurs désaturées)
;; |||||||   Notez que l'intensité des couleurs agit après cette valeur!
;; |||||||
;; ||||||+-- Désactiver le clipping des tuiles dans les 8 pixels de gauche
;; ||||||
;; |||||+--- Désactiver le clipping des sprites dans les 8 pixels de gauche
;; |||||
;; ||||+---- Activer l'affichage des tuiles
;; ||||
;; |||+----- Activer l'affichage des sprites
;; |||
;; ||+------ Augmenter l'intensité des rouges
;; ||
;; |+------- Augmenter l'intensité des verts
;; |
;; +-------- Augmenter l'intensité des bleus
;;
;;===========================================================================;;
;;=============================== Déclarations ==============================;;
;;===========================================================================;;

	.inesprg 1		; Banque de 1x 16KB de code PRG
	.ineschr 1		; Banque de 1x 8KB de données CHR
	.inesmap 0		; Aucune échange de banques
	.inesmir 1		; Mirroir du background

;;===========================================================================;;
;;============================== Initialisation =============================;;
;;===========================================================================;;

	.bank 0			; Banque 0
	.org $8000		; L'écriture commence à l'adresse $8000
	.code			; Début du programme

;;---------------------------------------------------------------------------;;
;;------ Reset: Initialise le PPU et le APU au démarrage du programme -------;;
;;---------------------------------------------------------------------------;;
Reset:
	SEI				; Désactive l'IRQ
	CLD				; Désactive le mode décimal
	LDX #%01000000	; Charge %01000000 (64) dans X
	STX $4017		; Place X dans $4017 et désactive le métronome du APU
	LDX #$FF		; Charge $FF (255) dans X
	TXS				; Initialise la pile à 255
	INX				; Incrémente X
	STX $2000		; Place X dans $2000 et désactive le NMI
	STX $2001		; Place X dans $2001 et désactive l'affichage
	STX $4010		; Place X dans $4010 et désactive le DMC
	JSR VBlank

;;---------------------------------------------------------------------------;;
;;-------------------- Clear: Remet la mémoire RAM à zéro -------------------;;
;;---------------------------------------------------------------------------;;
Clear:
	LDA #$00		; Charge $00 (0) dans A
	STA $0000, x	; Place A dans $00XX
	STA $0100, x	; Place A dans $01XX
	STA $0300, x	; Place A dans $03XX
	STA $0400, x	; Place A dans $04XX
	STA $0500, x	; Place A dans $05XX
	STA $0600, x	; Place A dans $06XX
	STA $0700, x	; Place A dans $07XX
	LDA #$FF		; Charge $FF (255) dans A
	STA $0200, x	; Place A dans $02XX
	INX				; Incrémente X
	BNE Clear		; Recommence Clear si X n'est pas 0
	JSR VBlank		; Attend un chargement d'image complet avant de continuer
	JSR PPUInit		; Initialise le PPU avant de charger le reste
	
;;---------------------------------------------------------------------------;;
;;--------- LoadPalettes: Charge les palettes de couleur en mémoire ---------;;
;;---------------------------------------------------------------------------;;
LoadPalettes:
	LDA $2002		; Lis l'état du PPU pour réinitialiser son latch
	LDA #$3F		; Charge l'octet le plus significatif ($3F) dans A
	STA $2006		; Place A dans $2006
	LDA #$00		; Charge l'octet le moins significatif ($00) dans A
	STA $2006		; Place A dans $2006
	LDY #$00		; Charge $00 (0) dans Y

;;---------------------------------------------------------------------------;;
;;----------- LoadPalettesLoop: Boucle de chargement des palettes -----------;;
;;---------------------------------------------------------------------------;;
LoadPalettesLoop:
	LDA Palette, y	; Charge le premier octet de la Palette (+ Y) dans A
	STA $2007		; Place A dans $2007
	INY				; Incrémente Y
	CPY #$20		; Compare Y avec $20 (32)
	BNE LoadPalettesLoop	; Recommence LoadPalettesLoop si Y < 32
  
;;---------------------------------------------------------------------------;;
;;--------------- LoadSprites: Charge les sprites en mémoire ----------------;;
;;---------------------------------------------------------------------------;;
LoadSprites:
	LDY #$00		; Charge $00 (0) dans Y

;;---------------------------------------------------------------------------;;
;;------------ LoadSpritesLoop: Boucle de chargement des sprites ------------;;
;;---------------------------------------------------------------------------;;
LoadSpritesLoop:
	LDA Sprites, y	; Charge le premier octet des Sprites (+ Y) dans A
	STA $0200, y	; Place A dans $02YY
	INY				; Incrémente Y
	CPY #$04		; Compare Y avec $04 (4)
	BNE LoadSpritesLoop		; Recommence LoadSpritesLoop si Y < 4
	JSR PPUInit		; Appelle l'initialisation du PPU

;;===========================================================================;;
;;=================================== Code ==================================;;
;;===========================================================================;;

;;---------------------------------------------------------------------------;;
;;------------------- Forever: Boucle infinie du programme ------------------;;
;;---------------------------------------------------------------------------;;
Forever:
	JMP Forever		; Recommence Forever jusqu'à la prochaine interruption

;;---------------------------------------------------------------------------;;
;;------------ NMI: Code d'affichage à chaque image du programme ------------;;
;;---------------------------------------------------------------------------;;
NMI:
;;############################# Votre code ici ##############################;;

;;---------------------------------------------------------------------------;;
;;------------------ End: Fin du NMI et retour au Forever -------------------;;
;;---------------------------------------------------------------------------;;
End:
	RTI				; Retourne au Forever à la fin du NMI

;;---------------------------------------------------------------------------;;
;;---------- PPUInit: Code d'affichage à chaque image du programme ----------;;
;;---------------------------------------------------------------------------;;
PPUInit:
	LDA #$00		; Charge $00 (0) dans A
	STA $2003		; Place A, l'octet le moins significatif ($00) dans $2003
	LDA #$02		; Charge $02 (2) dans A
	STA $4014		; Place A, l'octet le plus significatif ($02) dans $4014. 
					; Cela initie le transfert de l'adresse $0200 pour la RAM
	LDA #%10001000	; Charge les informations de contrôle du PPU dans A
	STA $2000		; Place A dans $2000
	LDA #%00011110	; Charge les informations de masque du PPU dans A
	STA $2001		; Place A dans $2001
	RTS				; Retourne à l'exécution parent
	
;;---------------------------------------------------------------------------;;
;;---------------- CancelScroll: Désactive le scroll du PPU -----------------;;
;;---------------------------------------------------------------------------;;
CancelScroll:
	LDA $2002		; Lis l'état du PPU pour réinitialiser son latch
	LDA #$00		; Charge $00 (0) dans A
	STA $2000		; Place A dans $2000 (Scroll X précis)
	STA $2006		; Place A dans $2006 (Scroll Y précis)
	STA $2005		; Place A dans $2005 (Table de tuiles)
	STA $2005		; Place A dans $2005 (Scroll Y grossier)
	STA $2006		; Place A dans $2006 (Scroll X grossier)
	
;;---------------------------------------------------------------------------;;
;;------------ VBlank: Attend la fin de l'affichage d'une image -------------;;
;;---------------------------------------------------------------------------;;
VBlank:
	BIT $2002		; Vérifie le 7e bit (PPU loaded) de l'adresse $2002
	BPL VBlank		; Recommence VBlank si l'image n'est pas chargée au complet
	RTS				; Retourne à l'exécution parent

;;===========================================================================;;
;;================================ Affichage ================================;;
;;===========================================================================;;

	.bank 1			; Banque 1
	.org $E000		; L'écriture commence à l'adresse $E000
	
;;---------------------------------------------------------------------------;;
;;----------- Palette: Palette de couleur du fond et des sprites ------------;;
;;---------------------------------------------------------------------------;;
Palette:
	.db $FE,$11,$21,$31, $FE,$05,$15,$25, $FE,$08,$18,$28, $FE,$0A,$1A,$2A
	; Les couleurs du fond se lisent comme suis: 
	; [Couleur de fond, Couleur 1, Couleur 2, Couleur 3], [...], ...
	.db $FE,$11,$21,$31, $FE,$05,$15,$25, $FE,$08,$18,$28, $FE,$0A,$1A,$2A
	; Les couleurs des sprites se lisent comme suis: 
	; [Couleur de transparence, Couleur 1, Couleur 2, Couleur 3], [...], ...
	
;;---------------------------------------------------------------------------;;
;;---------- Sprites: Position et attribut des sprites de départ ------------;;
;;---------------------------------------------------------------------------;;
Sprites:  
  .db $78, $00, %00000001, $78
  ; Les propriétés des sprites se lisent comme suit:
  ; [Position Y, Index du sprite, Attributs, Position X]

;;===========================================================================;;
;;============================== Interruptions ==============================;;
;;===========================================================================;;

	.org $FFFA		; L'écriture commence à l'adresse $FFFA
	.dw NMI			; Lance la sous-méthode NMI lorsque le NMI survient
	.dw Reset		; Lance la sous-méthode Reset au démarrage du processeur
	.dw 0			; Ne lance rien lorsque la commande BRK survient

;;===========================================================================;;
;;=============================== Background ================================;;
;;===========================================================================;;

	.bank 2			; Banque 2
	.org $0000		; L'écriture commence à l'adresse $0000
	
Tile0:
	.db %00001111
	.db %00001111
	.db %00001111
	.db %00001111
	.db %00001111
	.db %00001111
	.db %00001111
	.db %00001111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %11111111
	.db %11111111
	.db %11111111
	.db %11111111
	; Les pixels représentés ici sont les bits les plus significatifs

;;===========================================================================;;
;;================================ Sprites ==================================;;
;;===========================================================================;;
	
	.org $1000		; L'écriture commence à l'adresse $1000
	
Sprite0:
	.db %00111100
	.db %01111110
	.db %11111111
	.db %11111111
	.db %11111111
	.db %11111111
	.db %01111110
	.db %00111100
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00100100
	.db %00000000
	.db %00111100
	.db %00011000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

;;===========================================================================;;
;;============================== END OF FILE ================================;;
;;===========================================================================;;