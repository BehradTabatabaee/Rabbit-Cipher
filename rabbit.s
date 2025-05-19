.section .text
    .align  2
    .global rabbit_key_setup_
    .global rabbit_generate_keystream_
    .global rabbit_crypt_

.equ X_OFF,      0
.equ C_OFF,      32
.equ CARRY_OFF,  64

g_func:
    mul     x8, x0, x0
    lsr     x9, x8, #32
    eor     x0, x8, x9 
    and     x0, x0, #0xFFFFFFFF // Ensure 32-bit
    ret

rabbit_key_setup_:
    // Save FP, link register, and registers x19-x27
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #72]
    mov     x19, x0             // x19 = ctx
    mov     x20, x1             // x20 = key

    // Load key (little-endian)
    ldr     w2, [x20]
    ldr     w3, [x20, #4]
    ldr     w4, [x20, #8]
    ldr     w5, [x20, #12]

    // Initialize x[0,2,4,6]
    str     w2, [x19, #X_OFF]
    str     w3, [x19, #X_OFF+8]
    str     w4, [x19, #X_OFF+16]
    str     w5, [x19, #X_OFF+24]

    // Initialize x[1,3,5,7]
    lsl     w6, w5, #16       
    lsr     w7, w4, #16         
    orr     w6, w6, w7       
    str     w6, [x19, #X_OFF+4]
    lsl     w6, w2, #16       
    lsr     w7, w5, #16        
    orr     w6, w6, w7        
    str     w6, [x19, #X_OFF+12]
    lsl     w6, w3, #16     
    lsr     w7, w2, #16     
    orr     w6, w6, w7      
    str     w6, [x19, #X_OFF+20]
    lsl     w6, w4, #16     
    lsr     w7, w3, #16     
    orr     w6, w6, w7      
    str     w6, [x19, #X_OFF+28]

    // Initialize c[0,2,4,6]
    ror     w6, w4, #16       
    str     w6, [x19, #C_OFF]
    ror     w6, w5, #16       
    str     w6, [x19, #C_OFF+8]
    ror     w6, w2, #16      
    str     w6, [x19, #C_OFF+16]
    ror     w6, w3, #16     
    str     w6, [x19, #C_OFF+24]

    // Initialize c[1,3,5,7]
    and     w6, w2, #0xFFFF0000 
    and     w7, w3, #0x0000FFFF 
    orr     w6, w6, w7      
    str     w6, [x19, #C_OFF+4]
    and     w6, w3, #0xFFFF0000
    and     w7, w4, #0x0000FFFF
    orr     w6, w6, w7      
    str     w6, [x19, #C_OFF+12]
    and     w6, w4, #0xFFFF0000
    and     w7, w5, #0x0000FFFF
    orr     w6, w6, w7       
    str     w6, [x19, #C_OFF+20]
    and     w6, w5, #0xFFFF0000
    and     w7, w2, #0x0000FFFF
    orr     w6, w6, w7 
    str     w6, [x19, #C_OFF+28]

    // Initialize carry to 0
    str     wzr, [x19, #CARRY_OFF]
    mov     w20, #4
mix_loop:
    ldr     w21, [x19, #CARRY_OFF] 
    add     x22, x19, #C_OFF 
    mov     w23, #8 
counter_update_loop:
    ldr     w24, [x22]
    mov     w25, #0xD34D 
    movk    w25, #0x4D34, lsl #16 
    adds    w25, w25, w21  
    adds    w25, w25, w24   
    str     w25, [x22], #4     
    cset    w21, cs        
    subs    w23, w23, #1
    bne     counter_update_loop
    str     w21, [x19, #CARRY_OFF] 
    sub     sp, sp, #64
    mov     x23, sp
    mov     x24, #0 
    add     x25, x19, #X_OFF
    add     x26, x19, #C_OFF 
g_compute_loop:
    ldr     w0, [x25, x24, lsl #2]  // x[j]
    ldr     w1, [x26, x24, lsl #2]  // c[j]
    add     w0, w0, w1          // x[j] + c[j]
    bl      g_func
    str     w0, [x23, x24, lsl #2]  // store g(j)
    add     x24, x24, #1
    cmp     x24, #8
    blt     g_compute_loop

    // Update state x[j]
    mov     x24, #0             // j
    add     x25, x19, #X_OFF
state_update_loop:
    ldr     w0, [x23, x24, lsl #2] 
    add     x26, x24, #7
    and     x26, x26, #7 
    ldr     w1, [x23, x26, lsl #2]
    ror     w1, w1, #16 
    add     x27, x24, #6
    and     x27, x27, #7
    ldr     w2, [x23, x27, lsl #2]
    ror     w2, w2, #8
    eor     w0, w0, w1
    eor     w0, w0, w2
    str     w0, [x25, x24, lsl #2]  // x[j] = result
    add     x24, x24, #1
    cmp     x24, #8
    blt     state_update_loop
    add     sp, sp, #64 
    subs    w20, w20, #1
    bne     mix_loop

    // Restore registers and return
    ldr     x27, [sp, #72]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

rabbit_generate_keystream_:
    stp     x29, x30, [sp, #-80]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    stp     x25, x26, [sp, #64]
    str     x27, [sp, #72]
    mov     x19, x0 
    mov     x20, x1 
    ldr     w21, [x19, #CARRY_OFF]
    add     x22, x19, #C_OFF 
    mov     w23, #8 
ks_counter_update_loop:
    ldr     w24, [x22] 
    mov     w25, #0xD34D  
    movk    w25, #0x4D34, lsl #16
    adds    w25, w25, w21 
    adds    w25, w25, w24    
    str     w25, [x22], #4  
    cset    w21, cs         
    subs    w23, w23, #1
    bne     ks_counter_update_loop
    str     w21, [x19, #CARRY_OFF] 
    sub     sp, sp, #128     
    mov     x23, sp            
    add     x24, sp, #64  
    mov     x25, #0  
    add     x26, x19, #X_OFF
    add     x27, x19, #C_OFF 
ks_g_compute_loop:
    ldr     w0, [x26, x25, lsl #2]
    ldr     w1, [x27, x25, lsl #2]
    add     w0, w0, w1  
    bl      g_func 
    str     w0, [x23, x25, lsl #2]
    add     x25, x25, #1
    cmp     x25, #8
    blt     ks_g_compute_loop
    mov     x25, #0  
ks_next_x_compute_loop:
    ldr     w0, [x23, x25, lsl #2]
    add     x26, x25, #7
    and     x26, x26, #7      
    ldr     w1, [x23, x26, lsl #2] 
    ror     w1, w1, #16     
    add     x27, x25, #6
    and     x27, x27, #7     
    ldr     w2, [x23, x27, lsl #2]  
    ror     w2, w2, #8       
    eor     w0, w0, w1        
    eor     w0, w0, w2      
    str     w0, [x24, x25, lsl #2] 
    add     x25, x25, #1
    cmp     x25, #8
    blt     ks_next_x_compute_loop
    ldr     w0, [x24]     
    ldr     w1, [x24, #20]    
    lsr     w1, w1, #16        
    eor     w0, w0, w1         
    str     w0, [x20]          
    ldr     w0, [x24, #8]     
    ldr     w1, [x24, #28]     
    lsr     w1, w1, #16        
    eor     w0, w0, w1         
    str     w0, [x20, #4]     
    ldr     w0, [x24, #16]      
    ldr     w1, [x24, #4]      
    lsr     w1, w1, #16        
    eor     w0, w0, w1          
    str     w0, [x20, #8]     
    ldr     w0, [x24, #24]     
    ldr     w1, [x24, #12]      
    lsr     w1, w1, #16        
    eor     w0, w0, w1          
    str     w0, [x20, #12]   
    add     sp, sp, #128
    ldr     x27, [sp, #72]
    ldp     x25, x26, [sp, #64]
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #80
    ret

rabbit_crypt_:
    stp     x29, x30, [sp, #-64]!
    mov     x29, sp
    stp     x19, x20, [sp, #16]
    stp     x21, x22, [sp, #32]
    stp     x23, x24, [sp, #48]
    mov     x19, x0  
    mov     x20, x1       
    mov     x21, x2     
    sub     sp, sp, #16

crypt_loop:
    cbz     x21, crypt_done
    mov     x0, x19 
    mov     x1, sp    
    bl      rabbit_generate_keystream_
    mov     x22, #16
    cmp     x21, x22
    csel    x22, x21, x22, ls  
    mov     x23, #0  
xor_loop:
    ldrb    w0, [sp, x23]  
    ldrb    w1, [x20, x23]  
    eor     w0, w0, w1    
    strb    w0, [x20, x23]   
    add     x23, x23, #1
    cmp     x23, x22
    blt     xor_loop
    add     x20, x20, x22
    sub     x21, x21, x22
    b       crypt_loop
crypt_done:
    add     sp, sp, #16
    ldp     x23, x24, [sp, #48]
    ldp     x21, x22, [sp, #32]
    ldp     x19, x20, [sp, #16]
    ldp     x29, x30, [sp], #64
    ret