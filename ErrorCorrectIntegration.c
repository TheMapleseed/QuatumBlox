void apply_error_correction(QHiFFS_State *qs) {
    #pragma omp parallel for
    for (int i = 0; i < STATES; i += 8) {
        __m512d syndrome = _mm512_load_pd(&qs->state[i].real);
        __m512d correction = _mm512_fmadd_pd(syndrome, 
                            _mm512_set1_pd(1.0/sqrt(2)), 
                            _mm512_set1_pd(0.0));
        _mm512_store_pd(&qs->state[i].real, correction);
    }
}
