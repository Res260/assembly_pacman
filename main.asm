;;===========================================================================;;
;;========= PACMAN ET LES FANTÔMES GAMBADENT GAIEMENT DANS LA FORÊT =========;;
;;========= Produit par Émilio Gonzalez (Modèle de François Allard) =========;;
;;====================== Cégep de Drummondville - 2015 ======================;;
;;=====Pour le petit +, il faut appuyer sur A (player 1). C'est semsible=====;;
;;================car c'est un toggle, donc appuyer rapidement.==============;;
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
	CPY #$50		; Compare Y avec $50
	BNE LoadSpritesLoop		; Recommence LoadSpritesLoop si Y < $50
	JSR VBlank
;;-------------------------------------------------------------

LoadAttribute:
	LDA #$23
	STA $2006
	LDA #$C0
	STA $2006
	LDX #$00

LoadAttributeLoop:
	LDA #%00011011
	STA $2007
	INX
	CPX #64
	BNE LoadAttributeLoop

InitialiserGhosts:
	LDA #0
	STA directionGhost0
	LDA #1
	STA directionGhost1
	LDA #2
	STA directionGhost2
	LDA #3
	STA directionGhost3
	LDA #2
	STA fantomeSelectionne

;;-------------------------------------------------------------

	JSR CancelScroll
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
	JSR HandlePacmanMouth
	JSR ReadInput
	LDA tactiqueActivee
	CMP #1
	BEQ HandlePT
	JSR MovePacman
	JSR MoveGhost0
	JSR MoveGhost1
	JSR MoveGhost2
	JSR MoveGhost3
	JSR UpdatePacmanMouth

;;---------------------------------------------------------------------------;;
;;------------------ End: Fin du NMI et retour au Forever -------------------;;
;;---------------------------------------------------------------------------;;
End:
	LDA #$02
	STA $4014
	RTI				; Retourne au Forever à la fin du NMI

;;===========================================================================;;
;;                         SECTION IMPRESSIONNEZ-MOI                         ;;
;;===========================================================================;;

;;---------------------------------------------------------------------------;;
;;--Read1A: Appelle PositionTactique si la touche A du joueur 1 est enfoncée-;;
;;---------------------------------------------------------------------------;;
Read1A:
	AND #%00000001 ;Valider si le dernier bit est à 1 (le bouton appuyé).
	BNE PositionTactique ;Faire bouger Pacman vers le bas.
	RTS

;;---------------------------------------------------------------------------;;
;;------------PositionTactique: Toggle la position tactique.-----------------;;
;;---------------------------------------------------------------------------;;
PositionTactique:
	LDA #1
	EOR %00000001
	STA tactiqueActivee
	LDA #0
	STA tactiqueReady
	JSR PacmanDroite
	RTS

;;---------------------------------------------------------------------------;;
;;------------HandlePT: Gère la position tactique au complet.----------------;;
;;---------------------------------------------------------------------------;;
HandlePT:
	JSR UpdatePacmanMouth
	LDA tactiqueReady
	CMP #1
	BEQ VolAerien
	JSR SetTactiqueReadyTrue
	JSR MovePacManPT
	JSR MoveGhost0PT
	JSR MoveGhost1PT
	JSR MoveGhost2PT
	JSR MoveGhost3PT

	JMP End

;;---------------------------------------------------------------------------;;
;;------------VolAerien: Déplace les sprites vers la droite.-----------------;;
;;---------------------------------------------------------------------------;;
VolAerien:
	JSR MoveRight
	JSR MoveGhost0Droite
	JSR MoveGhost1Droite
	JSR MoveGhost2Droite
	JSR MoveGhost3Droite
	JMP End

;;---------------------------------------------------------------------------;;
;;------------MoveWPT: Appelle MoveWXPT et MoveWYPT--------------------------;;
;;---------------------------------------------------------------------------;;
MovePacManPT:
	JSR MovePacmanYPT
	JSR MovePacmanXPT
	RTS

MoveGhost0PT:
	JSR MoveGhost0YPT
	JSR MoveGhost0XPT
	RTS

MoveGhost1PT:
	JSR MoveGhost1YPT
	JSR MoveGhost1XPT
	RTS

MoveGhost2PT:
	JSR MoveGhost2YPT
	JSR MoveGhost2XPT
	RTS

MoveGhost3PT:
	JSR MoveGhost3YPT
	JSR MoveGhost3XPT
	RTS

;;---------------------------------------------------------------------------;;
;;------------MoveW(X|Y)PT: Bouge W pour l'ammener à sa position ------------;;
;;---------------------------------------------------------------------------;;
MovePacmanYPT:
	LDA $0200
	CMP #$74
	BEQ GoFin
	JSR SetTactiqueReadyFalse
	JMP MoveDown
	RTS

GoFin:
	JMP Fin

MovePacmanXPT:
	LDA $0203
	CMP #$80
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveRight
	RTS

MoveGhost0YPT:
	LDA $0210
	CMP #$84
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost0Haut
	RTS

MoveGhost0XPT:
	LDA $0213
	CMP #$70
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost0Droite
	RTS

MoveGhost1YPT:
	LDA $0224
	CMP #$66
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost1Haut
	RTS

MoveGhost1XPT:
	LDA $0227
	CMP #$78
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost1Droite
	RTS

MoveGhost2YPT:
	LDA $0230
	CMP #$58
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost2Haut
	RTS

MoveGhost2XPT:
	LDA $0237
	CMP #$68
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost2Droite
	RTS

MoveGhost3YPT:
	LDA $0240
	CMP #$92
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost3Haut
	RTS

MoveGhost3XPT:
	LDA $0243
	CMP #$60
	BEQ Fin
	JSR SetTactiqueReadyFalse
	JMP MoveGhost3Droite
	RTS

Fin:
	RTS

;;---------------------------------------------------------------------------;;
;;------------SetTactiqueReadyBool: met tactiqueReady à true ou false--------;;
;;---------------------------------------------------------------------------;;
SetTactiqueReadyTrue:
	LDA #1
	STA tactiqueReady
	RTS


SetTactiqueReadyFalse:
	LDA #0
	STA tactiqueReady
	RTS

;;===========================================================================;;
;;             FIN SECTION IMPRESSIONNEZ-MOI (ARE YOU IMPRESSED??)           ;;
;;===========================================================================;;

MovePacman:
	LDA directionPacman
	CMP #0
	BEQ MoveRight
	CMP #1
	BEQ MoveDown
	CMP #2
	BEQ MoveLeft
	CMP #3
	BEQ MoveUp
	RTS

;;---------------------------------------------------------------------------;;
;;------------MoveX: Déplace les sprites de Pacman vers le/la X--------------;;
;;---------------------------------------------------------------------------;;
MoveUp:
	DEC $0200
	DEC $0204
	DEC $0208
	DEC $020C
	RTS

MoveDown:
	INC $0200
	INC $0204
	INC $0208
	INC $020C
	RTS

MoveLeft:
	DEC $0203
	DEC $0207
	DEC $020B
	DEC $020F
	RTS

MoveRight:
	INC $0203
	INC $0207
	INC $020B
	INC $020F
	RTS

;;---------------------------------------------------------------------------;;
;;------------ReadInput: Lis le controlleur puis appelle le reste------------;;
;;---------------------------------------------------------------------------;;
ReadInput:
	LDA #$01 
	STA $4016
	LDA #$00
	STA $4016
	;Controlleur 1
	LDA $4016 ; A... POSITION TACTIQUE D'ATTAQUE AÉRIENNE
	JSR Read1A
	LDA tactiqueActivee
	CMP #1
	BEQ DoRTS
	LDA $4016 ; B... Ignorer
	LDA $4016 ; Select... Ignorer
	LDA $4016 ; Start... Ignorer
	LDA $4016 ; Haut... Faire bouger pacman vers le haut si appuyé.
	JSR ReadHaut

	LDA $4016 ; Bas... Faire bouger pacman vers le bas si appuyé.
	JSR ReadBas
	LDA $4016 ;Gauche
	JSR ReadGauche
	LDA $4016 ;Droite
	JSR ReadDroite
	;Controlleur 2
	LDA $4017 ;A
	JSR ReadAGhost
	LDA $4017 ;B
	JSR ReadBGhost
	LDA $4017 ;Select
	JSR ReadSelectGhost
	LDA $4017 ;Start
	JSR ReadStartGhost
	LDA $4017 ;Haut
	JSR ReadHautGhost
	LDA $4017 ;Bas
	JSR ReadBasGhost
	LDA $4017 ;Gauche
	JSR ReadGaucheGhost
	LDA $4017 ;Droite
	JSR ReadDroiteGhost
	RTS

DoRTS:
	RTS

;;---------------------------------------------------------------------------;;
;;-----------ReadX... Effectue la comparaison pour savoir si le -------------;;
;;-------------- bouton est appuyé. Si oui, appelle PacmanX -----------------;;
;;---------------------------------------------------------------------------;;
ReadDroite:
	AND #%00000001 ;Valider si le dernier bit est à 1 (le bouton appuyé).
	BNE PacmanDroite ;Faire bouger Pacman vers la droite.
	RTS

;;---------------------------------------------------------------------------;;
;;-------------PacmanX... Réorganise les sprites pour faire que -------------;;
;;--------------------- Pacman fait face vers le/la X -----------------------;;
;;---------------------------------------------------------------------------;;
PacmanDroite:
	LDA #0 ;0 étant vers la droite
	STA directionPacman
	;Sprite en haut à gauche
	LDA #0
	STA $0201
	LDA $0202
	AND #%00111111 ;annule les miroirs
	STA $0202
	;Sprite en haut à droite
	LDA #1         ;sprite #1
	STA $0205
	LDA $0206
	AND #%00111111 ;annule les miroirs
	STA $0206
	;Sprite en bas à gauche
	LDA #2         ;sprite #2
	STA $0209
	LDA $020A
	AND #%00111111 ;annule les miroirs
	ORA #%00000000 ;miroir
	STA $020A
	;Sprite en bas à droite
	LDA #3         ;sprite #3
	STA $020D
	LDA $020E
	AND #%00111111 ;annule les miroirs
	STA $020E
	RTS

ReadBas:
	AND #%00000001 ;Valider si le dernier bit est à 1 (le bouton appuyé).
	BNE PacmanBas ;Faire bouger Pacman vers le bas.
	RTS

PacmanBas:
	LDA #1 ;1 étant vers le bas
	STA directionPacman
	;Sprite en haut à gauche
	LDA #2		   ;sprite #2
	STA $0201
	LDA $0202
	AND #%00111111 ;annule les miroirs
	ORA #%10000000 ;miroir
	STA $0202
	;Sprite en haut à droite
	LDA #0         ;sprite #0
	STA $0205
	LDA $0206
	AND #%00111111 ;annule les miroirs
	ORA #%01000000 ;miroirs
	STA $0206
	;Sprite en bas à gauche
	LDA #3         ;sprite #3
	STA $0209
	LDA $020A
	AND #%00111111 ;annule les miroirs
	ORA #%01000000 ;miroir
	STA $020A
	;Sprite en bas à droite
	LDA #1         ;sprite #1
	STA $020D
	LDA $020E
	AND #%00111111 ;annule les miroirs
	ORA #%10000000 ;miroir
	STA $020E
	RTS

ReadGauche:
	AND #%00000001 ;Valider si le dernier bit est à 1 (le bouton appuyé).
	BNE PacmanGauche ;Faire bouger Pacman vers la gauche.
	RTS

PacmanGauche:
	LDA #2 ;2 étant vers la gauche
	STA directionPacman
	;Sprite en haut à gauche
	LDA #1
	STA $0201
	LDA $0202
	AND #%00111111 ;annule les miroirs
	ORA #%01000000
	STA $0202
	;Sprite en haut à droite
	LDA #0
	STA $0205
	LDA $0206
	AND #%00111111 ;annule les miroirs
	ORA #%01000000
	STA $0206
	;Sprite en bas à gauche
	LDA #3         ;sprite #3
	STA $0209
	LDA $020A
	AND #%00111111 ;annule les miroirs
	ORA #%01000000 ;miroir
	STA $020A
	;Sprite en bas à droite
	LDA #2         ;sprite #2
	STA $020D
	LDA $020E
	AND #%00111111 ;annule les miroirs
	ORA #%01000000 ;miroir
	STA $020E
	RTS

ReadHaut:
	AND #%00000001 ;Valider si le dernier bit est à 1 (le bouton appuyé).
	BNE PacmanHaut ;Faire bouger Pacman vers le haut.
	RTS

PacmanHaut:
	LDA #3 ;3 étant vers le haut
	STA directionPacman
	;Sprite en haut à gauche
	LDA #1
	STA $0201
	LDA $0202
	AND #%00111111
	ORA #%01000000
	STA $0202
	;Sprite en haut à droite
	LDA #3
	STA $0205
	LDA $0206
	AND #%00111111
	ORA #%10000000
	STA $0206
	;Sprite en bas à gauche
	LDA #0         ;sprite #0
	STA $0209
	LDA $020A
	AND #%00111111 ;annule les miroirs
	ORA #%10000000 ;miroir
	STA $020A
	;Sprite en bas à droite
	LDA #2         ;sprite #2
	STA $020D
	LDA $020E
	AND #%00111111 ;annule les miroirs
	ORA #%01000000 ;miroirs
	STA $020E
	RTS

HydroQuebec:
	TAX
	TAX
	TAX
	TAX
	TAX

;;---------------------------------------------------------------------------;;
;;----------HandlePacmanMouth: monte le compteur pour le changement----------;;
;;---------d'état de la bouche de Pacman et appelle ChangePacmanMouth--------;;
;;----------------------quand on doit changer son état.----------------------;;
;;---------------------------------------------------------------------------;;
HandlePacmanMouth:
	INC compteurPacman    ;Augmente compteurPacman de 1;
	LDX compteurPacman 
	CPX #$0F              ;Compare compteurPacman avec #$0F
	BEQ ChangePacmanMouth
	RTS

;;---------------------------------------------------------------------------;;
;;--------------ChangePacmanMouth: remet le compteur à 0 et -----------------;;
;;----------------------"toggle" boucheOuverte à 0 ou 1 ---------------------;;
;;---------------------------------------------------------------------------;;
ChangePacmanMouth:
	LDA #0
	STA compteurPacman ;Remet le compteur pour la bouche à 0
	LDA boucheOuverte
	EOR #%00000001
	STA boucheOuverte
	RTS

;;---------------------------------------------------------------------------;;
;;----------UpdatePacmanMouth: Appelle OuvreBouche ou FermeBouche------------;;
;;----------------------selon ce qui doit changer.---------------------------;;
;;---------------------------------------------------------------------------;;
UpdatePacmanMouth:
	LDA boucheOuverte
	AND #%00000001
	BNE OuvreBouche

;;---------------------------------------------------------------------------;;
;;--------------FermeBouche: Appelle FermeBoucheX selon la ------------------;;
;;------------------------direction de Pacman--------------------------------;;
;;---------------------------------------------------------------------------;;
FermeBouche:
	LDA directionPacman
	CMP #0
	BEQ FermeBoucheDroite
	CMP #1
	BEQ FermeBoucheBas
	CMP #2
	BEQ FermeBoucheGauche
	CMP #3
	BEQ FermeBoucheHaut
	RTS

;;---------------------------------------------------------------------------;;
;;--------------FermeBoucheX: Change les sprites quand Pacman----------------;;
;;-------------- se dirige vers le/la X pour fermer sa bouche----------------;;
;;---------------------------------------------------------------------------;;
FermeBoucheDroite:
	LDA #1	           ;Sprite Pacman10
	STA $0205          ;Change le sprite de Pacman en haut à droite;
	LDA #3			   ;Sprite Pacman30
	STA $020D          ;Change le sprite de Pacman en bas à droite;
	RTS

FermeBoucheBas:
	LDA #3          ;Sprite Pacman30
	STA $0209       ;Change le sprite de Pacman en bas à gauche;
	LDA #1          ;Sprite Pacman10
	STA $020D       ;Change le sprite de Pacman en bas à droite;
	RTS

FermeBoucheGauche:
	LDA #1           ;Sprite Pacman10
	STA $0201        ;Change le sprite de Pacman en haut à gauche;
	LDA #3          ;Sprite Pacman30
	STA $0209        ;Change le sprite de Pacman en bas à gauche;
	RTS

FermeBoucheHaut:
	LDA #1           ;Sprite Pacman30
	STA $0201        ;Change le sprite de Pacman en haut à gauche;
	LDA #3          ;Sprite Pacman10
	STA $0205        ;Change le sprite de Pacman en haut à droite;
	RTS

;;---------------------------------------------------------------------------;;
;;--------------OuvreBouche: Appelle OuvreBoucheX selon la ------------------;;
;;------------------------direction de Pacman--------------------------------;;
;;---------------------------------------------------------------------------;;
OuvreBouche:
	LDA directionPacman
	CMP #0
	BEQ OuvreBoucheDroite
	CMP #1
	BEQ OuvreBoucheBas
	CMP #2
	BEQ OuvreBoucheGauche
	CMP #3
	BEQ OuvreBoucheHaut
	RTS

;;---------------------------------------------------------------------------;;
;;--------------OuvreBoucheX: Change les sprites quand Pacman----------------;;
;;-------------- se dirige vers le/la X pour ouvrir sa bouche----------------;;
;;---------------------------------------------------------------------------;;
OuvreBoucheDroite:
	LDA #$04           ;Sprite Pacman11
	STA $0205          ;Change le sprite de Pacman en haut à droite;
	LDA #$05		   ;Sprite Pacman31
	STA $020D          ;Change le sprite de Pacman en bas à droite;
	RTS

OuvreBoucheBas:
	LDA #15          ;Sprite Pacman31
	STA $0209        ;Change le sprite de Pacman en bas à gauche;
	LDA #14          ;Sprite Pacman11
	STA $020D        ;Change le sprite de Pacman en bas à droite;
	RTS

OuvreBoucheGauche:
	LDA #4           ;Sprite Pacman4
	STA $0201        ;Change le sprite de Pacman en haut à gauche;
	LDA #5          ;Sprite Pacman11
	STA $0209        ;Change le sprite de Pacman en bas à gauche;
	RTS

OuvreBoucheHaut:
	LDA #14           ;Sprite Pacman4
	STA $0201        ;Change le sprite de Pacman en haut à gauche;
	LDA #15          ;Sprite Pacman11
	STA $0205        ;Change le sprite de Pacman en haut à droite;
	RTS

;;---------------------------------------------------------------------------;;
;;------------------------------Fantômes-------------------------------------;;
;;---------------------------------------------------------------------------;;

;;---------------------------------------------------------------------------;;
;;-----------------ReadXGhost: Branche à XSelected si X est appuyé-----------;;
;;---------------------------------------------------------------------------;;
ReadAGhost:
	AND #%00000001 ;Vérifier si appuyé
	BNE ASelected ;Si oui, changer fantomeSelectionne
	RTS

;;---------------------------------------------------------------------------;;
;;----XSelected: met la valeur d'un fantôme dans fantomeSelectionne ---------;;
;;---------------------------------------------------------------------------;;
ASelected:
	LDA #0
	STA fantomeSelectionne
	RTS

ReadBGhost:
	AND #%00000001 ;Vérifier si appuyé
	BNE BSelected ;Si oui, changer fantomeSelectionne
	RTS

BSelected:
	LDA #1
	STA fantomeSelectionne
	RTS

ReadStartGhost:
	AND #%00000001 ;Vérifier si appuyé
	BNE StartSelected ;Si oui, changer fantomeSelectionne
	RTS

StartSelected:
	LDA #2
	STA fantomeSelectionne
	RTS

ReadSelectGhost:
	AND #%00000001 ;Vérifier si appuyé
	BNE SelectSelected ;Si oui, changer fantomeSelectionne
	RTS

SelectSelected:
	LDA #3
	STA fantomeSelectionne
	RTS

ReadHautGhost:
	AND #%00000001          ;Vérifier si bien appuyé
	BEQ Return 				;Si non, retourner à la lecture des touches
	LDA fantomeSelectionne  ;Si oui, faire monter le bon ghost
	CMP #0
	BEQ GoHautGhost0
	CMP #1
	BEQ GoHautGhost1
	CMP #2
	BEQ GoHautGhost2
	CMP #3
	BEQ GoHautGhost3
	RTS

;;---------------------------------------------------------------------------;;
;;--------------GoXGhostN: update directionGhostN pour dire que la-----------;;
;;------------------------direction de GhostN change ------------------------;;
;;---------------------------------------------------------------------------;;
GoHautGhost0:
	LDA #3
	STA directionGhost0
	RTS

GoHautGhost1:
	LDA #3
	STA directionGhost1
	RTS

GoHautGhost2:
	LDA #3
	STA directionGhost2
	RTS

GoHautGhost3:
	LDA #3
	STA directionGhost3
	RTS

ReadBasGhost:
	AND #%00000001          ;Vérifier si bien appuyé
	BEQ Return 				;Si non, retourner à la lecture des touches
	LDA fantomeSelectionne  ;Si oui, faire monter le bon ghost
	CMP #0
	BEQ GoBasGhost0
	CMP #1
	BEQ GoBasGhost1
	CMP #2
	BEQ GoBasGhost2
	CMP #3
	BEQ GoBasGhost3
	RTS

GoBasGhost0:
	LDA #1
	STA directionGhost0
	RTS

GoBasGhost1:
	LDA #1
	STA directionGhost1
	RTS

GoBasGhost2:
	LDA #1
	STA directionGhost2
	RTS

GoBasGhost3:
	LDA #1
	STA directionGhost3
	RTS

;;---------------------------------------------------------------------------;;
;;----------------------Return: fait simplement un RTS ----------------------;;
;;---------------------------------------------------------------------------;;
Return:
	RTS

ReadGaucheGhost:
	AND #%00000001          ;Vérifier si bien appuyé
	BEQ Return 				;Si non, retourner à la lecture des touches
	LDA fantomeSelectionne  ;Si oui, faire monter le bon ghost
	CMP #0
	BEQ GoGaucheGhost0
	CMP #1
	BEQ GoGaucheGhost1
	CMP #2
	BEQ GoGaucheGhost2
	CMP #3
	BEQ GoGaucheGhost3
	RTS

GoGaucheGhost0:
	LDA #2
	STA directionGhost0
	RTS

GoGaucheGhost1:
	LDA #2
	STA directionGhost1
	RTS

GoGaucheGhost2:
	LDA #2
	STA directionGhost2
	RTS

GoGaucheGhost3:
	LDA #2
	STA directionGhost3
	RTS

ReadDroiteGhost:
	AND #%00000001          ;Vérifier si bien appuyé
	BEQ Return 				;Si non, retourner à la lecture des touches
	LDA fantomeSelectionne  ;Si oui, faire monter le bon ghost
	CMP #0
	BEQ GoDroiteGhost0
	CMP #1
	BEQ GoDroiteGhost1
	CMP #2
	BEQ GoDroiteGhost2
	CMP #3
	BEQ GoDroiteGhost3
	RTS

GoDroiteGhost0:
	LDA #0
	STA directionGhost0
	RTS

GoDroiteGhost1:
	LDA #0
	STA directionGhost1
	RTS

GoDroiteGhost2:
	LDA #0
	STA directionGhost2
	RTS

GoDroiteGhost3:
	LDA #0
	STA directionGhost3
	RTS


;;---------------------------------------------------------------------------;;
;;--------------MoveGhostN: Appelle MoveGhostNX selon directionGhostN--------;;
;;---------------------------------------------------------------------------;;
MoveGhost0:
	LDA directionGhost0
	CMP #0
	BEQ MoveGhost0Droite
	CMP #1
	BEQ MoveGhost0Bas
	CMP #2
	BEQ MoveGhost0Gauche
	CMP #3
	BEQ MoveGhost0Haut
	RTS

;;---------------------------------------------------------------------------;;
;;----------------MoveGhostNX: Déplace les sprites de ghostN ----------------;;
;;---------------------------------------------------------------------------;;
MoveGhost0Droite:
	INC $0213
	INC $0217
	INC $021B
	INC $021F
	RTS

MoveGhost0Bas:
	INC $0210
	INC $0214
	INC $0218
	INC $021C
	RTS

MoveGhost0Gauche:
	DEC $0213
	DEC $0217
	DEC $021B
	DEC $021F
	RTS

MoveGhost0Haut:
	DEC $0210
	DEC $0214
	DEC $0218
	DEC $021C
	RTS

MoveGhost1:
	LDA directionGhost1
	CMP #0
	BEQ MoveGhost1Droite
	CMP #1
	BEQ MoveGhost1Bas
	CMP #2
	BEQ MoveGhost1Gauche
	CMP #3
	BEQ MoveGhost1Haut
	RTS

MoveGhost1Droite:
	INC $0223
	INC $0227
	INC $022B
	INC $022F
	RTS

MoveGhost1Bas:
	INC $0220
	INC $0224
	INC $0228
	INC $022C
	RTS

MoveGhost1Gauche:
	DEC $0223
	DEC $0227
	DEC $022B
	DEC $022F
	RTS

MoveGhost1Haut:
	DEC $0220
	DEC $0224
	DEC $0228
	DEC $022C
	RTS

MoveGhost2:
	LDA directionGhost2
	CMP #0
	BEQ MoveGhost2Droite
	CMP #1
	BEQ MoveGhost2Bas
	CMP #2
	BEQ MoveGhost2Gauche
	CMP #3
	BEQ MoveGhost2Haut
	RTS

MoveGhost2Droite:
	INC $0233
	INC $0237
	INC $023B
	INC $023F
	RTS

MoveGhost2Bas:
	INC $0230
	INC $0234
	INC $0238
	INC $023C
	RTS

MoveGhost2Gauche:
	DEC $0233
	DEC $0237
	DEC $023B
	DEC $023F
	RTS

MoveGhost2Haut:
	DEC $0230
	DEC $0234
	DEC $0238
	DEC $023C
	RTS

MoveGhost3:
	LDA directionGhost3
	CMP #0
	BEQ MoveGhost3Droite
	CMP #1
	BEQ MoveGhost3Bas
	CMP #2
	BEQ MoveGhost3Gauche
	CMP #3
	BEQ MoveGhost3Haut
	RTS

MoveGhost3Droite:
	INC $0243
	INC $0247
	INC $024B
	INC $024F
	RTS

MoveGhost3Bas:
	INC $0240
	INC $0244
	INC $0248
	INC $024C
	RTS

MoveGhost3Gauche:
	DEC $0243
	DEC $0247
	DEC $024B
	DEC $024F
	RTS

MoveGhost3Haut:
	DEC $0240
	DEC $0244
	DEC $0248
	DEC $024C
	RTS

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
	RTS
	
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
	.db $FE,$10,$00,$2D, $FE,$38,$28,$18, $FE,$33,$23,$13, $FE,$3A,$2A,$1A
	; Les couleurs du fond se lisent comme suis: 
	; [Couleur de fond, Couleur 1, Couleur 2, Couleur 3], [...], ...
	.db $FE,$26,$27,$28, $FE,$03,$2D,$08, $FE,$1A,$24,$11, $FE,$0A,$1A,$2A
	; Les couleurs des sprites se lisent comme suis: 
	; [Couleur de transparence, Couleur 1, Couleur 2, Couleur 3], [...], ...
	
;;---------------------------------------------------------------------------;;
;;---------- Sprites: Position et attribut des sprites de départ ------------;;
;;---------------------------------------------------------------------------;;
Sprites:  
  .db $40, 0, %00000000, $10 ;Pacman0     $0200
  ; Les propriétés des sprites se lisent comme suit:
  ; [Position Y, Index du sprite, Attributs, Position X]
  .db $40, 1, %00000000, $18 ;Pacman1     $0204
  .db $48, 2, %00000000, $10 ;Pacman2     $0208
  .db $48, 3, %00000000, $18 ;Pacman3     $020C

  .db $58, 6, %00000010, $10 ;Ghost00     $0210
  .db $58, 7, %00000010, $18 ;Ghost01     $0214
  .db $60, 8, %00000010, $10 ;Ghost02     $0218
  .db $60, 9, %00000010, $18 ;Ghost03     $021C

  .db $68, 6, %00000001, $10 ;Ghost10     $0220
  .db $68, 7, %00000001, $18 ;Ghost11     $0224
  .db $70, 8, %00000001, $10 ;Ghost12     $0228
  .db $70, 9, %00000001, $18 ;Ghost13     $022C

  .db $78, 10, %00000010, $10 ;Ghost20    $0230
  .db $78, 11, %00000010, $18 ;Ghost21    $0234
  .db $80, 12, %00000010, $10 ;Ghost22    $0238
  .db $80, 13, %00000010, $18 ;Ghost23    $023C

  .db $88, 10, %00000001, $10 ;Ghost30    $0240
  .db $88, 11, %00000001, $18 ;Ghost31    $0244
  .db $90, 12, %00000001, $10 ;Ghost32    $0248
  .db $90, 13, %00000001, $18 ;Ghost33    $024C

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
	.db %00000000
	.db %00111000
	.db %01000100
	.db %00001000
	.db %00010000
	.db %00010000
	.db %00000000
	.db %00010000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

;;===========================================================================;;
;;================================ Sprites ==================================;;
;;===========================================================================;;
	
	.org $1000		; L'écriture commence à l'adresse $1000
	
Pacman0:
	.db %00000011
	.db %00001111
	.db %00111111
	.db %00111111
	.db %01111111
	.db %01111111
	.db %11111111
	.db %11111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00001000
	.db %00000000
	.db %01000000
	.db %00000010
	.db %00001000
	.db %10000000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman10:
	.db %11000000
	.db %11110000
	.db %11111100
	.db %11111100
	.db %10011110
	.db %10011110
	.db %11111111
	.db %11111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %01000000
	.db %00100000
	.db %00000000
	.db %00000000
	.db %00000100
	.db %00100000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman2:
	.db %11111111
	.db %11111111
	.db %01111111
	.db %01111111
	.db %00111111
	.db %00111111
	.db %00001111
	.db %00000011
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000100
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman30:
	.db %11111111
	.db %11111111
	.db %11111110
	.db %11111110
	.db %11111100
	.db %11111100
	.db %11110000
	.db %11000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %01000100
	.db %00000000
	.db %00100000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman11:
	.db %11000000
	.db %11110000
	.db %11111100
	.db %11111100
	.db %10011110
	.db %10011100
	.db %11100000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %01000000
	.db %10000000
	.db %00001000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman31:
	.db %00000000
	.db %11100000
	.db %11111100
	.db %11111110
	.db %11111100
	.db %11111100
	.db %11110000
	.db %11000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %01000000
	.db %00001000
	.db %00000000
	.db %11000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost00:
	.db %00000011
	.db %00001111
	.db %00011111
	.db %00010001
	.db %00110001
	.db %01110001
	.db %01111111
	.db %01111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost01:
	.db %11000000
	.db %11110000
	.db %11111000
	.db %10001000
	.db %10001100
	.db %10001110
	.db %11111110
	.db %11111110
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost02:
	.db %01111111
	.db %01111111
	.db %01101111
	.db %01000110
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost03:
	.db %11111110
	.db %11111110
	.db %11110110
	.db %01100010
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost10:
	.db %00000011
	.db %00001111
	.db %00011111
	.db %00010001
	.db %00110001
	.db %01110001
	.db %01111111
	.db %01111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000011
	.db %00001111
	.db %00011111
	.db %00010001
	.db %00110001
	.db %01110001
	.db %01111111
	.db %01111111
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost11:
	.db %11000000
	.db %11110000
	.db %11111000
	.db %10001000
	.db %10001100
	.db %10001110
	.db %11111110
	.db %11111110
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %11000000
	.db %11110000
	.db %11111000
	.db %10001000
	.db %10001100
	.db %10001110
	.db %11111110
	.db %11111110
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost12:
	.db %01111111
	.db %01111111
	.db %01101111
	.db %01000110
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %01111111
	.db %01111111
	.db %01101111
	.db %01000110
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Ghost13:
	.db %11111110
	.db %11111110
	.db %11110110
	.db %01100010
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %11111110
	.db %11111110
	.db %11110110
	.db %01100010
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman12:
	.db %00000000
	.db %00010000
	.db %00111100
	.db %00111100
	.db %00111110
	.db %01001110
	.db %01001111
	.db %01111111
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00000000
	.db %00001000
	.db %00000000
	.db %00000000
	.db %00000010
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs

Pacman32:
	.db %01111111
	.db %01111111
	.db %01111110
	.db %00111110
	.db %00111100
	.db %00111100
	.db %00010000
	.db %00000000
	; Les pixels représentés ici sont les bits les moins significatifs

	.db %00000000
	.db %00100000
	.db %00010000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	.db %00000000
	; Les pixels représentés ici sont les bits les plus significatifs


;;===========================================================================;;
;;=============================== VARIABLES =================================;;
;;===========================================================================;;

	.bank 0
	.zp
	.org $0000

compteurPacman  .ds 1 ;pour savoir quand toggle la bouche
boucheOuverte   .ds 1 ;1 si bouche est ouverte 0 si fermée
directionPacman .ds 1 ;0droite 1bas 2gauche 3haut
fantomeSelectionne .ds 1 ;0 Ghost0 1 Ghost1 2 Ghost2 3Ghost3
directionGhost0 .ds 1 ;0droite 1bas 2gauche 3haut
directionGhost1 .ds 1 ;0droite 1bas 2gauche 3haut
directionGhost2 .ds 1 ;0droite 1bas 2gauche 3haut
directionGhost3 .ds 1 ;0droite 1bas 2gauche 3haut
tactiqueActivee .ds 1 ;1 si la position tactique d'attaque aérienne est activée.
tactiqueReady   .ds 1 ;1 si la position tactique d'attaque aérienne est
                      ;prête/en cours.

;;===========================================================================;;
;;============================== END OF FILE ================================;;
;;===========================================================================;;