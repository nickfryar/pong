.segment "HEADER"
.byte "NES", $1a
.byte $02
.byte $01
.byte %00000001
.byte $00, $00, $00, $00
.byte $00, $00, $00, $00, $00

.struct Entity
    xpos   .byte 1
    ypos   .byte 1
    width  .byte 1
    height .byte 1
    xspeed .byte 1
    yspeed .byte 1
.endstruct

.segment "ZEROPAGE"
controller1: .res 1
controller2: .res 1

.segment "DATA"
; screen boundary constants
TOP_BOUNDARY    = $10
BOT_BOUNDARY    = $10

; paddle constants
PADDLE_WIDTH    = $08
PADDLE_HEIGHT   = $20
PADDLE_SPEED_Y  = $04

; paddle 1 constants
PADDLE1_START_X = $10
PADDLE1_START_Y = $40

; paddle 2 constants
PADDLE2_START_X = $E7
PADDLE2_START_Y = $80

; ball constants
BALL_START_X    = $7C
BALL_START_Y    = $6C
BALL_WIDTH      = $08
BALL_HEIGHT     = $08
BALL_SPEED_X    = $02
BALL_SPEED_Y    = $04

; entities
ball:    .res .sizeof(Entity)
paddle1: .res .sizeof(Entity)
paddle2: .res .sizeof(Entity)

.segment "STARTUP"

.segment "CODE"
WaitForVBlank:
    BIT $2002
    BPL WaitForVBlank
    RTS

FlipSign:
    EOR #$FF
    CLC
    ADC #%00000001
    RTS

Reset:
    SEI ; disable interrupts
    CLD ; sisable decimal mode

    ; disable sound IRQ
    LDX #$40
    STX $4017

    ; initialize stack register
    LDX #$FF
    TXS

    INX ; FF+1 -> 00

    ; zero out the PPU registers
    STX $2000
    STX $2001

    STX $4010

    JSR WaitForVBlank

    TXA

ClearMem:
    STA $0000, X ; $0000 => $00FF
    STA $0100, X ; $0100 => $01FF
    STA $0300, X
    STA $0400, X
    STA $0500, X
    STA $0600, X
    STA $0700, X
    LDA #$FF
    STA $0200, X ; $0200 => $02FF
    LDA #$00
    INX
    BNE ClearMem

    JSR WaitForVBlank

    LDA #$02
    STA $4014
    NOP

LoadPalettes:
    LDA #$3F
    STA $2006
    LDA #$00
    STA $2006 ; 3F00
    LDX #$00
LoadPalettesLoop:
    LDA PaletteData, X
    STA $2007 ; 3F00, 3F01, 3F02 -> 3F1F
    INX
    CPX #$20
    BNE LoadPalettesLoop

    LDX #$00
LoadSprites:
    LDA SpriteData, X
    STA $0200, X
    INX
    CPX #$40
    BNE LoadSprites
    
    CLI ; enable interrupts
    LDA #%10010000
    STA $2000 ; PPUCTRL
    LDA #%00011110
    STA $2001 ; PPUMASK

Initialize:
    ; initialize ball
    LDA #BALL_START_X
    STA ball+Entity::xpos
    LDA #BALL_START_Y
    STA ball+Entity::ypos
    LDA #BALL_WIDTH
    STA ball+Entity::width
    LDA #BALL_HEIGHT
    STA ball+Entity::height
    LDA #BALL_SPEED_X
    STA ball+Entity::xspeed
    LDA #BALL_SPEED_Y
    STA ball+Entity::yspeed

    ; initialize paddle 1
    LDA #PADDLE1_START_X
    STA paddle1+Entity::xpos
    LDA #PADDLE1_START_Y
    STA paddle1+Entity::ypos
    LDA #PADDLE_WIDTH
    STA paddle1+Entity::width
    LDA #PADDLE_HEIGHT
    STA paddle1+Entity::height
    LDA #PADDLE_SPEED_Y
    STA paddle1+Entity::yspeed

    ; initialize paddle 2
    LDA #PADDLE2_START_X
    STA paddle2+Entity::xpos
    LDA #PADDLE2_START_Y
    STA paddle2+Entity::ypos
    LDA #PADDLE_WIDTH
    STA paddle2+Entity::width
    LDA #PADDLE_HEIGHT
    STA paddle2+Entity::height
    LDA #PADDLE_SPEED_Y
    STA paddle2+Entity::yspeed

    JSR WaitForVBlank

    JMP Update

LatchControllers:
    LDA #$01
    STA $4016
    LDA #$00
    STA $4016
    RTS

PollControllers:
    LDX #$00
    STX controller1
    STX controller2
PollControllersLoop:
    LDA $4016
    LSR A
    ROL controller1
    LDA $4017
    LSR A
    ROL controller2
    INX
    CPX #$08
    BNE PollControllersLoop
    RTS

DetectCollisionLeftPaddle:
    ; ball.x < paddle.x + paddle.width
    CLC
    LDA paddle1+Entity::xpos
    ADC paddle1+Entity::width
    CMP ball+Entity::xpos
    LDA #$00
    BCC DetectCollisionLeftPaddleEnd
    ; paddle.y < ball.y + ball.height
    CLC
    LDA ball+Entity::ypos
    ADC ball+Entity::height
    CMP paddle1+Entity::ypos
    LDA #$00
    BCC DetectCollisionLeftPaddleEnd
    ; ball.y < paddle.y + paddle.height
    CLC
    LDA paddle1+Entity::ypos
    ADC paddle1+Entity::height
    CMP ball+Entity::ypos
    LDA #$00
    BCC DetectCollisionLeftPaddleEnd
    LDA #$01
DetectCollisionLeftPaddleEnd:
    RTS

DetectCollisionRightPaddle:
    ; paddle.x < ball.x + ball.width
    CLC
    LDA ball+Entity::xpos
    ADC ball+Entity::width
    CMP paddle2+Entity::xpos
    LDA #$00
    BCC DetectCollisionRightPaddleEnd
    ; paddle.y < ball.y + paddle.height
    CLC
    LDA ball+Entity::ypos
    ADC ball+Entity::height
    CMP paddle2+Entity::ypos
    LDA #$00
    BCC DetectCollisionRightPaddleEnd
    ; ball.y < paddle.y + paddle.height
    CLC
    LDA paddle2+Entity::ypos
    ADC paddle2+Entity::height
    CMP ball+Entity::ypos
    LDA #$00
    BCC DetectCollisionRightPaddleEnd
    LDA #$01
DetectCollisionRightPaddleEnd:
    RTS

DidBallPassLeftBoundary:
    LDA paddle1+Entity::xpos
    CMP ball+Entity::xpos
    LDA #$00
    BCC :+
    LDA #$01
    :
    RTS

DidBallPassRightBoundary:
    LDA paddle2+Entity::xpos
    CMP ball+Entity::xpos
    LDA #$00
    BCS :+
    LDA #$01
    :
    RTS

BallScore:
    ; reset ball position
    LDA #BALL_START_X
    STA ball+Entity::xpos
    LDA #BALL_START_Y
    STA ball+Entity::ypos
    ; flip ball x speed
    LDA ball+Entity::xspeed
    JSR FlipSign
    STA ball+Entity::xspeed
    ; flip ball y speed
    LDA ball+Entity::yspeed
    JSR FlipSign
    STA ball+Entity::yspeed

UpdateBallX:
    ; update xpos
    SEC
    LDA ball+Entity::xspeed
    CMP #$00
    BCC :+
    ; if xpeed < 0, clear carry before LDA
    CLC
    :
    ADC ball+Entity::xpos
    STA ball+Entity::xpos
    RTS

UpdateBallY:
    ; update ypos
    SEC
    LDA ball+Entity::yspeed
    CMP #$00
    BCC :+
    ; if yspeed < 0, clear carry before LDA
    CLC
    :
    LDA ball+Entity::ypos
    ADC ball+Entity::yspeed
    STA ball+Entity::ypos
    RTS

DidBallPassTopBoundary:
    LDA ball+Entity::ypos
    SEC
    SBC #TOP_BOUNDARY
    LDA #$00
    BCS :+
    LDA #$01
    :
    RTS

BallDidPassTopBoundary:
    ; set ball.ypos = top boundary + 1
    LDA #TOP_BOUNDARY
    CLC
    ADC #$01
    STA ball+Entity::ypos
    ; flip yspeed
    LDA ball+Entity::yspeed
    JSR FlipSign
    STA ball+Entity::yspeed
    RTS

DidBallPassBottomBoundary:
    LDA ball+Entity::ypos
    CLC
    ADC ball+Entity::height
    ADC #BOT_BOUNDARY
    ADC #$10
    LDA #$00
    BCC :+
    LDA #$01
    :
    RTS

BallDidPassBottomBoundary:
    ; set ball.ypos = 240 - bottom boundary - ball.height - 1
    LDA #$F0
    SEC
    SBC #BOT_BOUNDARY
    SBC ball+Entity::height
    SBC #$01
    STA ball+Entity::ypos
    ; flip yspeed
    LDA ball+Entity::yspeed
    JSR FlipSign
    STA ball+Entity::yspeed
    RTS

UpdateBall:
    ; update ball position
    JSR UpdateBallX
    JSR UpdateBallY
    ; check top screen boundary
    JSR DidBallPassTopBoundary
    CMP #$00
    BEQ :+
    JSR BallDidPassTopBoundary
    :
    ; check bottom screen boundary
    JSR DidBallPassBottomBoundary
    CMP #$00
    BEQ :+
    JSR BallDidPassBottomBoundary
    :
    ; check left screen boundary
    JSR DidBallPassLeftBoundary
    CMP #$00
    BEQ :+
    JSR BallScore
    :
    ; check right screen boundary
    JSR DidBallPassRightBoundary
    CMP #$00
    BEQ :+
    JSR BallScore
    :
    ; check left paddle
    JSR DetectCollisionLeftPaddle
    CMP #$00
    BEQ :+
    LDA ball+Entity::xspeed
    JSR FlipSign
    STA ball+Entity::xspeed
    :
    ; check right paddle
    JSR DetectCollisionRightPaddle
    CMP #$00
    BEQ :+
    LDA ball+Entity::xspeed
    JSR FlipSign
    STA ball+Entity::xspeed
    :
    RTS

UpdatePaddle1:
    ; down pressed
    LDA controller1
    AND #%00000100
    BEQ :+
    CLC
    LDA paddle1+Entity::ypos
    ADC paddle1+Entity::yspeed
    STA paddle1+Entity::ypos
    :
    ; up pressed
    LDA controller1
    AND #%00001000
    BEQ :+
    SEC
    LDA paddle1+Entity::ypos
    SBC paddle1+Entity::yspeed
    STA paddle1+Entity::ypos
    :
    RTS

UpdatePaddle2:
    ; down pressed
    LDA controller2
    AND #%00000100
    BEQ :+
    CLC
    LDA paddle2+Entity::ypos
    ADC paddle2+Entity::yspeed
    STA paddle2+Entity::ypos
    :
    ; up pressed
    LDA controller2
    AND #%00001000
    BEQ :+
    SEC
    LDA paddle2+Entity::ypos
    SBC paddle2+Entity::yspeed
    STA paddle2+Entity::ypos
    :
    RTS

Update:
    ; get controller inputs
    JSR LatchControllers
    JSR PollControllers

    ; update sprites
    JSR UpdateBall
    JSR UpdatePaddle1
    JSR UpdatePaddle2

    ; wait for next frame
    JSR WaitForVBlank
    JMP Update

DrawBall:
    LDA ball+Entity::xpos
    STA $0223
    LDA ball+Entity::ypos
    STA $0220
    RTS

DrawPaddle1:
    CLC
    LDA paddle1+Entity::xpos
    STA $0203
    STA $0207
    STA $020B
    STA $020F
    LDA paddle1+Entity::ypos
    STA $0200
    ADC #$08
    STA $0204
    ADC #$08
    STA $0208
    ADC #$08
    STA $020C
    RTS

DrawPaddle2:
    CLC
    LDA paddle2+Entity::xpos
    STA $0213
    STA $0217
    STA $021B
    STA $021F
    LDA paddle2+Entity::ypos
    STA $0210
    ADC #$08
    STA $0214
    ADC #$08
    STA $0218
    ADC #$08
    STA $021C
    RTS

Draw:
    ; draw sprites
    JSR DrawBall
    JSR DrawPaddle1
    JSR DrawPaddle2

    LDA #$02
    STA $4014 ; set PPU sprite data address
    RTS

NMI:
    JSR Draw
    RTI

PaletteData:
  .byte $FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; background palette data
  .byte $20,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF  ; sprite palette data

SpriteData:
    .incbin "spritedata.bin"

.segment "VECTORS"
    .word NMI
    .word Reset

.segment "CHARS"
    .incbin "game.chr"