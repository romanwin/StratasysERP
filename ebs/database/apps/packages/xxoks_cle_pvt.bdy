CREATE OR REPLACE PACKAGE BODY xxoks_cle_pvt AS
   /* $Header: OKCSCLEB.pls 120.14.12000000.2 2008/05/16 09:02:25 sjanakir ship $ */

   l_debug VARCHAR2(1) := nvl(fnd_profile.VALUE('AFLOG_ENABLED'), 'N');

   /************************ HAND-CODED *********************************/
   FUNCTION validate_attributes(p_clev_rec IN clev_rec_type) RETURN VARCHAR2;
   g_no_parent_record CONSTANT VARCHAR2(200) := 'OKC_NO_PARENT_RECORD';
   g_unexpected_error CONSTANT VARCHAR2(200) := 'OKC_CONTRACTS_UNEXPECTED_ERROR';
   g_sqlerrm_token    CONSTANT VARCHAR2(200) := 'ERROR_MESSAGE';
   g_sqlcode_token    CONSTANT VARCHAR2(200) := 'ERROR_CODE';
   g_view             CONSTANT VARCHAR2(200) := 'OKC_K_LINES_V';
   g_exception_halt_validation EXCEPTION;
   l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;

   -- Start of comments
   --
   -- Procedure Name  : validate_line_number
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_line_number(x_return_status OUT NOCOPY VARCHAR2,
                                  p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('100: Entered validate_line_number', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.line_number = okc_api.g_miss_char OR
         p_clev_rec.line_number IS NULL) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_required_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'line_number');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         -- halt validation
         RAISE g_exception_halt_validation;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('200: Leaving validate_line_number with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('300: Exiting validate_line_number:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('400: Exiting validate_line_number:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_line_number;

   -- Start of comments
   --
   -- Procedure Name  : validate_chr_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_chr_id(x_return_status OUT NOCOPY VARCHAR2,
                             p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_chrv_csr IS
         SELECT 'x'
         --npalepu 08-11-2005 modified for bug # 4691662.
         --Replaced table okc_k_headers_b with headers_All_b table
         /* from OKC_K_HEADERS_B */
           FROM okc_k_headers_all_b
         --end npalepu
          WHERE id = p_clev_rec.chr_id;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('500: Entered validate_chr_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.chr_id <> okc_api.g_miss_num AND
         p_clev_rec.chr_id IS NOT NULL) THEN
         OPEN l_chrv_csr;
         FETCH l_chrv_csr
            INTO l_dummy_var;
         CLOSE l_chrv_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'chr_id',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'OKC_K_HEADERS_V');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('600: Leaving validate_chr_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('700: Exiting validate_chr_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_chrv_csr%ISOPEN THEN
            CLOSE l_chrv_csr;
         END IF;
      
   END validate_chr_id;

   -- Start of comments
   --
   -- Procedure Name  : validate_cle_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_cle_id(x_return_status OUT NOCOPY VARCHAR2,
                             p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_clev_csr IS
         SELECT 'x' FROM okc_k_lines_b WHERE id = p_clev_rec.cle_id;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('800: Entered validate_cle_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.cle_id <> okc_api.g_miss_num AND
         p_clev_rec.cle_id IS NOT NULL) THEN
         OPEN l_clev_csr;
         FETCH l_clev_csr
            INTO l_dummy_var;
         CLOSE l_clev_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'cle_id',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => g_view);
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('900: Leaving validate_cle_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('1000: Exiting validate_cle_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_clev_csr%ISOPEN THEN
            CLOSE l_clev_csr;
         END IF;
      
   END validate_cle_id;

   -- Start of comments
   --
   -- Procedure Name  : validate_lse_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_lse_id(x_return_status OUT NOCOPY VARCHAR2,
                             p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      -- Rajendra
      l_access_level VARCHAR2(1);
      --
      CURSOR l_lslv_csr IS
         SELECT 'x' FROM okc_line_styles_v WHERE id = p_clev_rec.lse_id;
      CURSOR c_lines61(p_chr_id NUMBER, p_cle_id NUMBER) IS
         SELECT 'x'
           FROM okc_k_lines_b
          WHERE chr_id = p_chr_id AND
                id <> nvl(p_cle_id, -1) AND
                lse_id = 61;
      -- Rajendra
      CURSOR c_access_level IS
         SELECT access_level
           FROM okc_line_styles_v
          WHERE id = p_clev_rec.lse_id;
      --
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('1100: Entered validate_lse_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.lse_id = okc_api.g_miss_num OR
         p_clev_rec.lse_id IS NULL) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_required_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'lse_id');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         -- halt validation
         RAISE g_exception_halt_validation;
      END IF;
   
      -- Rajendra
      OPEN c_access_level;
      FETCH c_access_level
         INTO l_access_level;
      CLOSE c_access_level;
   
      IF l_access_level = 'U' THEN
         -- If user defined line style
         --
         -- enforce foreign key
         OPEN l_lslv_csr;
         FETCH l_lslv_csr
            INTO l_dummy_var;
         CLOSE l_lslv_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'lse_id',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'OKC_LINE_STYLES_V');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         ELSIF (p_clev_rec.lse_id = 61 AND p_clev_rec.chr_id IS NOT NULL AND
               p_clev_rec.cle_id IS NULL) THEN
            l_dummy_var := '?';
            -- Should be just one Price Hold TopLine
            OPEN c_lines61(p_clev_rec.chr_id, p_clev_rec.id);
            FETCH c_lines61
               INTO l_dummy_var;
            CLOSE c_lines61;
         
            -- if l_dummy_var still set to default, data was not found
            IF (l_dummy_var <> '?') THEN
               okc_api.set_message(p_app_name => g_app_name,
                                   p_msg_name => 'OKC_JUST_1_PH_TOPLINE_ALLOWED');
               -- notify caller of an error
               x_return_status := okc_api.g_ret_sts_error;
            END IF;
         END IF;
         -- Rajendra
      END IF; -- if user defined line style
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('1200: Leaving validate_lse_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('1300: Exiting validate_lse_id:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('1400: Exiting validate_lse_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_lslv_csr%ISOPEN THEN
            CLOSE l_lslv_csr;
         END IF;
      
   END validate_lse_id;

   -- Start of comments
   --
   -- Procedure Name  : validate_display_sequence
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_display_sequence(x_return_status OUT NOCOPY VARCHAR2,
                                       p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('1500: Entered validate_display_sequence', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.display_sequence = okc_api.g_miss_num OR
         p_clev_rec.display_sequence IS NULL) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_required_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'display_sequence');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         -- halt validation
         RAISE g_exception_halt_validation;
      END IF;
   
      -- check for display sequence > 0
      IF (p_clev_rec.display_sequence < 0) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_invalid_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'display_sequence');
         x_return_status := okc_api.g_ret_sts_error;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('1600: Leaving validate_display_sequence with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('1700: Exiting validate_display_sequence:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('1800: Exiting validate_display_sequence:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_display_sequence;

   -- Start of comments
   --
   -- Procedure Name  : validate_trn_code
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_trn_code(x_return_status OUT NOCOPY VARCHAR2,
                               p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('1900: Entered validate_trn_code', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key if data exists
      IF (p_clev_rec.trn_code <> okc_api.g_miss_char AND
         p_clev_rec.trn_code IS NOT NULL) THEN
         -- Check if the value is a valid code from lookup table
         x_return_status := okc_util.check_lookup_code('OKC_TERMINATION_REASON',
                                                       p_clev_rec.trn_code);
         IF (x_return_status = okc_api.g_ret_sts_error) THEN
            --set error message in message stack
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'TERMINATION_REASON');
            RAISE g_exception_halt_validation;
         ELSIF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('2000: Leaving validate_trn_code with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('2100: Exiting validate_trn_code:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_trn_code;

   -- Start of comments
   --
   -- Procedure Name  : validate_dnz_chr_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_dnz_chr_id(x_return_status OUT NOCOPY VARCHAR2,
                                 p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_chrv_csr IS
         SELECT 'x'
         --npalepu 08-11-2005 modified for bug # 4691662.
         --Replaced table okc_k_headers_b with headers_All_b table
         /* from OKC_K_HEADERS_B */
           FROM okc_k_headers_all_b
         --end npalepu
          WHERE id = p_clev_rec.dnz_chr_id;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('2200: Entered validate_dnz_chr_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
      -- check that data exists
      IF (p_clev_rec.dnz_chr_id = okc_api.g_miss_num OR
         p_clev_rec.dnz_chr_id IS NULL) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_required_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'dnz_chr_id');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         -- halt validation
         RAISE g_exception_halt_validation;
      END IF;
   
      -- enforce foreign key
      OPEN l_chrv_csr;
      FETCH l_chrv_csr
         INTO l_dummy_var;
      CLOSE l_chrv_csr;
   
      -- if l_dummy_var still set to default, data was not found
      IF (l_dummy_var = '?') THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_no_parent_record,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'dnz_chr_id',
                             p_token2       => g_child_table_token,
                             p_token2_value => g_view,
                             p_token3       => g_parent_table_token,
                             p_token3_value => 'OKC_K_HEADERS_V');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('2300: Leaving validate_dnz_chr_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('2400: Exiting validate_dnz_chr_id:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('2500: Exiting validate_dnz_chr_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_chrv_csr%ISOPEN THEN
            CLOSE l_chrv_csr;
         END IF;
      
   END validate_dnz_chr_id;

   -- Start of comments
   --
   -- Procedure Name  : validate_exception_yn
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_exception_yn(x_return_status OUT NOCOPY VARCHAR2,
                                   p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('2600: Entered validate_exception_yn', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.exception_yn = okc_api.g_miss_char OR
         p_clev_rec.exception_yn IS NULL) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_required_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'exception_yn');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         -- halt validation
         RAISE g_exception_halt_validation;
      END IF;
   
      -- check allowed values
      IF (upper(p_clev_rec.exception_yn) NOT IN ('Y', 'N')) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_invalid_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'exception_yn');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('2700: Leaving validate_exception_yn with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('2800: Exiting validate_exception_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('2900: Exiting validate_exception_yn:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_exception_yn;

   -- Start of comments
   --
   -- Procedure Name  : validate_hidden_ind
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_hidden_ind(x_return_status OUT NOCOPY VARCHAR2,
                                 p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('3000: Entered validate_hidden_ind', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
      IF (p_clev_rec.hidden_ind <> okc_api.g_miss_char AND
         p_clev_rec.hidden_ind IS NOT NULL) THEN
         -- check allowed values
         IF (upper(p_clev_rec.hidden_ind) NOT IN ('Y', 'N')) THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'hidden_ind');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('3100: Leaving validate_hidden_ind with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('3200: Exiting validate_hidden_ind:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_hidden_ind;

   -- Start of comments
   --
   -- Procedure Name  : validate_price_level_ind
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_price_level_ind(x_return_status OUT NOCOPY VARCHAR2,
                                      p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('3300: Entered validate_price_level_ind', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      IF (p_clev_rec.price_level_ind <> okc_api.g_miss_char AND
         p_clev_rec.price_level_ind IS NOT NULL) THEN
         -- check allowed values
         IF (upper(p_clev_rec.price_level_ind) NOT IN ('Y', 'N')) THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'price_level_ind');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('3400: Leaving validate_price_level_ind with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('3500: Exiting validate_price_level_ind:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_price_level_ind;

   -- Start of comments
   --
   -- Procedure Name  : validate_inv_line_level_ind
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_inv_line_level_ind(x_return_status OUT NOCOPY VARCHAR2,
                                         p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('3600: Entered validate_inv_line_level_ind', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      IF (p_clev_rec.invoice_line_level_ind <> okc_api.g_miss_char AND
         p_clev_rec.invoice_line_level_ind IS NOT NULL) THEN
         -- check allowed values
         IF (upper(p_clev_rec.invoice_line_level_ind) NOT IN ('Y', 'N')) THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'invoice_line_level_ind');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('3700: Leaving validate_inv_line_level_ind with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('3800: Exiting validate_inv_line_level_ind:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_inv_line_level_ind;

   -- Start of comments
   --
   -- Procedure Name  : validate_price_type
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_price_type(x_return_status OUT NOCOPY VARCHAR2,
                                 p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('3900: Entered validate_price_type', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check data is in lookup table only if data is not null
      IF (p_clev_rec.price_type <> okc_api.g_miss_char AND
         p_clev_rec.price_type IS NOT NULL) THEN
         -- Check if the value is a valid code from lookup table
         x_return_status := okc_util.check_lookup_code('OKC_PRICE_TYPE',
                                                       p_clev_rec.price_type);
         IF (x_return_status = okc_api.g_ret_sts_error) THEN
            --set error message in message stack
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'PRICE_TYPE');
            RAISE g_exception_halt_validation;
         ELSIF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('4000: Leaving validate_price_type with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('4100: Exiting validate_price_type:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('4200: Exiting validate_price_type:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_price_type;

   -- Start of comments
   --
   -- Procedure Name  : validate_sts_code
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_sts_code(x_return_status OUT NOCOPY VARCHAR2,
                               p_clev_rec      IN clev_rec_type) IS
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_stsv_csr(p_code IN VARCHAR2) IS
         SELECT 'x' FROM okc_statuses_b WHERE okc_statuses_b.code = p_code;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('4300: Entered validate_sts_code', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.sts_code = okc_api.g_miss_char OR
         p_clev_rec.sts_code IS NULL) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_required_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'sts_code');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         -- halt validation
         RAISE g_exception_halt_validation;
      END IF;
   
      -- Check foreign key
      OPEN l_stsv_csr(p_clev_rec.sts_code);
      FETCH l_stsv_csr
         INTO l_dummy_var;
      CLOSE l_stsv_csr;
   
      IF (l_dummy_var = '?') THEN
         --set error message in message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_no_parent_record,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'sts_code',
                             p_token2       => g_child_table_token,
                             p_token2_value => g_view,
                             p_token3       => g_parent_table_token,
                             p_token3_value => 'OKC_STATUSES_V');
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('4400: Leaving validate_sts_code with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('4500: Exiting validate_sts_code:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('4600: Exiting validate_sts_code:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_sts_code;

   -- Start of comments
   --
   -- Procedure Name  : validate_currency_code
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_currency_code(x_return_status OUT NOCOPY VARCHAR2,
                                    p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_fndv_csr IS
         SELECT 'x'
           FROM fnd_currencies_vl
          WHERE currency_code = p_clev_rec.currency_code AND
                enabled_flag = 'Y' AND
                SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
                nvl(end_date_active, SYSDATE);
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('4700: Entered validate_currency_code', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check data is in lookup table only if data is not null
      IF (p_clev_rec.currency_code <> okc_api.g_miss_char AND
         p_clev_rec.currency_code IS NOT NULL) THEN
         OPEN l_fndv_csr;
         FETCH l_fndv_csr
            INTO l_dummy_var;
         CLOSE l_fndv_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'currency_code',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'FND_CURRENCIES');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('4800: Leaving validate_currency_code with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('4900: Exiting validate_currency_code:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_fndv_csr%ISOPEN THEN
            CLOSE l_fndv_csr;
         END IF;
      
   END validate_currency_code;

   -- Start of comments
   --
   -- Procedure Name  : validate_start_date
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_start_date(x_return_status OUT NOCOPY VARCHAR2,
                                 p_clev_rec      IN clev_rec_type) IS
      l_start_date DATE;
      l_end_date   DATE;
      l_not_found  BOOLEAN;
      no_header_found EXCEPTION;
   
      -- Cursor to get header start and end dates
      CURSOR l_chrv_csr IS
         SELECT start_date, end_date
         --npalepu 08-11-2005 modified for bug # 4691662.
         --Replaced table okc_k_headers_b with headers_All_b table
         /* FROM OKC_K_HEADERS_B */
           FROM okc_k_headers_all_b
         --end npalepu
          WHERE id = p_clev_rec.dnz_chr_id;
   
      -- Cursor to get parent line's start and end dates
      CURSOR l_clev_csr IS
         SELECT start_date, end_date
           FROM okc_k_lines_b
          WHERE id = p_clev_rec.cle_id;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('5000: Entered validate_start_date', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.start_date <> okc_api.g_miss_date AND
         p_clev_rec.start_date IS NOT NULL) THEN
         IF (p_clev_rec.chr_id IS NOT NULL AND
            p_clev_rec.chr_id <> okc_api.g_miss_num) THEN
            OPEN l_chrv_csr;
            FETCH l_chrv_csr
               INTO l_start_date, l_end_date;
            l_not_found := l_chrv_csr%NOTFOUND;
            CLOSE l_chrv_csr;
         ELSIF (p_clev_rec.cle_id IS NOT NULL AND
               p_clev_rec.cle_id <> okc_api.g_miss_num) THEN
            OPEN l_clev_csr;
            FETCH l_clev_csr
               INTO l_start_date, l_end_date;
            l_not_found := l_clev_csr%NOTFOUND;
            CLOSE l_clev_csr;
         END IF;
      
         IF (l_not_found) THEN
            x_return_status := okc_api.g_ret_sts_error;
            RAISE no_header_found;
         END IF;
         IF (l_start_date IS NOT NULL AND l_end_date IS NOT NULL) THEN
            IF (trunc(p_clev_rec.start_date) < trunc(l_start_date) OR
               trunc(p_clev_rec.start_date) > trunc(l_end_date)) THEN
               x_return_status := okc_api.g_ret_sts_error;
            END IF;
            /* --Bug-1970094 --------------------------------------------------
                  Elsif (l_start_date IS NOT NULL and
                     p_clev_rec.start_date < l_start_date)
                  Then
            -------------------------------------------------------------------*/
         ELSIF (l_start_date IS NOT NULL AND
               trunc(p_clev_rec.start_date) < trunc(l_start_date)) THEN
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (x_return_status = okc_api.g_ret_sts_error) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => 'OKC_WRONG_CHILD_DATE',
                             p_token1       => 'VALUE1',
                             p_token1_value => 'Line Start Date');
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('5100: Leaving validate_start_date with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN no_header_found THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('5200: Exiting validate_start_date:NO_HEADER_FOUND Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => 'OKC_NOT_FOUND',
                             p_token1       => 'VALUE1',
                             p_token1_value => 'Start/End Dates',
                             p_token2       => 'VALUE2',
                             p_token2_value => 'OKC_K_HEADERS_V');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('5300: Exiting validate_start_date:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_start_date;

   -- Start of comments
   --
   -- Procedure Name  : validate_end_date
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_end_date(x_return_status OUT NOCOPY VARCHAR2,
                               p_clev_rec      IN clev_rec_type) IS
      l_start_date DATE;
      l_end_date   DATE;
      l_not_found  BOOLEAN;
      no_header_found EXCEPTION;
   
      -- Cursor to get header start and end dates
      CURSOR l_chrv_csr IS
         SELECT start_date, end_date
         --npalepu 08-11-2005 modified for bug # 4691662.
         --Replaced table okc_k_headers_b with headers_All_b table
         /* FROM OKC_K_HEADERS_B */
           FROM okc_k_headers_all_b
         --end npalepu
          WHERE id = p_clev_rec.dnz_chr_id;
   
      -- Cursor to get parent line's start and end dates
      CURSOR l_clev_csr IS
         SELECT start_date, end_date
           FROM okc_k_lines_b
          WHERE id = p_clev_rec.cle_id;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('5400: Entered validate_end_date', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.end_date <> okc_api.g_miss_date AND
         p_clev_rec.end_date IS NOT NULL) THEN
         IF (p_clev_rec.chr_id IS NOT NULL AND
            p_clev_rec.chr_id <> okc_api.g_miss_num) THEN
            OPEN l_chrv_csr;
            FETCH l_chrv_csr
               INTO l_start_date, l_end_date;
            l_not_found := l_chrv_csr%NOTFOUND;
            CLOSE l_chrv_csr;
         ELSIF (p_clev_rec.cle_id IS NOT NULL AND
               p_clev_rec.cle_id <> okc_api.g_miss_num) THEN
            OPEN l_clev_csr;
            FETCH l_clev_csr
               INTO l_start_date, l_end_date;
            l_not_found := l_clev_csr%NOTFOUND;
            CLOSE l_clev_csr;
         END IF;
      
         IF (l_not_found) THEN
            x_return_status := okc_api.g_ret_sts_error;
            RAISE no_header_found;
         END IF;
         IF (l_start_date IS NOT NULL AND l_end_date IS NOT NULL) THEN
            IF (trunc(p_clev_rec.end_date) < trunc(l_start_date) OR
               trunc(p_clev_rec.end_date) > trunc(l_end_date)) THEN
               x_return_status := okc_api.g_ret_sts_error;
            END IF;
         ELSIF (l_end_date IS NOT NULL AND
               trunc(p_clev_rec.end_date) > trunc(l_end_date)) THEN
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (x_return_status = okc_api.g_ret_sts_error) THEN
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => 'OKC_WRONG_CHILD_DATE',
                             p_token1       => 'VALUE1',
                             p_token1_value => 'Line End Date');
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('5500: Leaving validate_end_date with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN no_header_found THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('5600: Exiting validate_end_date:NO_HEADER_FOUND Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => 'OKC_NOT_FOUND',
                             p_token1       => 'VALUE1',
                             p_token1_value => 'Start/End Dates',
                             p_token2       => 'VALUE2',
                             p_token2_value => 'OKC_K_HEADERS_V');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('5700: Exiting validate_end_date:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_end_date;

   -- Start of comments
   --
   -- Procedure Name  : validate_line_renewal_type
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_line_renewal_type(x_return_status OUT NOCOPY VARCHAR2,
                                        p_clev_rec      IN clev_rec_type) IS
   
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('5711: Entered validate_line_renewal_type', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.line_renewal_type_code <> okc_api.g_miss_char OR
         p_clev_rec.line_renewal_type_code IS NOT NULL) THEN
         -- Check if the value is a valid code from lookup table
         x_return_status := okc_util.check_lookup_code('OKC_LINE_RENEWAL_TYPE',
                                                       p_clev_rec.line_renewal_type_code);
      
         IF (x_return_status = okc_api.g_ret_sts_error) THEN
            --set error message in message stack
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'LINE_RENEWAL_TYPE');
         
         ELSIF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
      IF (l_debug = 'Y') THEN
         okc_debug.log('5712: Exiting validate_line_renewal_type with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
   
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('5713: Exiting validate_line_renewal_type:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_line_renewal_type;

   ----------end rules validation

   PROCEDURE get_next_line_number(p_chr_id        IN NUMBER,
                                  p_cle_id        IN NUMBER,
                                  x_return_status OUT NOCOPY VARCHAR2,
                                  x_line_number   OUT NOCOPY NUMBER) IS
      -- cursor to get next line number if parent is header
      CURSOR l_clev_csr1 IS
         SELECT line_number FROM okc_k_lines_b WHERE chr_id = p_chr_id;
   
      -- cursor to get next line number if parent is another line
      CURSOR l_clev_csr2 IS
         SELECT line_number FROM okc_k_lines_b WHERE cle_id = p_cle_id;
      l_line_number_n NUMBER;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('5800: Entered get_next_line_number', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
      x_line_number   := 0;
   
      IF (p_chr_id IS NOT NULL) THEN
         -- get next line number in the first level of lines
         FOR l_rec IN l_clev_csr1 LOOP
            BEGIN
            
               IF (l_debug = 'Y') THEN
                  okc_debug.set_indentation('OKC_CLE_PVT');
                  okc_debug.log('5900: Entered get_next_line_number', 2);
               END IF;
            
               l_line_number_n := to_number(l_rec.line_number);
               IF (x_line_number < l_line_number_n) THEN
                  x_line_number := l_line_number_n;
               END IF;
            
               IF (l_debug = 'Y') THEN
                  okc_debug.log('6000: Leaving get_next_line_number', 2);
                  okc_debug.reset_indentation;
               END IF;
            
            EXCEPTION
               WHEN OTHERS THEN
               
                  IF (l_debug = 'Y') THEN
                     okc_debug.log('6100: Exiting get_next_line_number:OTHERS Exception',
                                   2);
                     okc_debug.reset_indentation;
                  END IF;
               
                  NULL;
            END;
         END LOOP;
      ELSIF (p_cle_id IS NOT NULL) THEN
         -- get next line number for this level of lines
         FOR l_rec IN l_clev_csr2 LOOP
            BEGIN
            
               IF (l_debug = 'Y') THEN
                  okc_debug.set_indentation('OKC_CLE_PVT');
                  okc_debug.log('6200: Entered get_next_line_number', 2);
               END IF;
            
               l_line_number_n := to_number(l_rec.line_number);
               IF (x_line_number < l_line_number_n) THEN
                  x_line_number := l_line_number_n;
               END IF;
            
               IF (l_debug = 'Y') THEN
                  okc_debug.log('6300: Leaving get_next_line_number', 2);
                  okc_debug.reset_indentation;
               END IF;
            
            EXCEPTION
               WHEN OTHERS THEN
               
                  IF (l_debug = 'Y') THEN
                     okc_debug.log('6400: Exiting get_next_line_number:OTHERS Exception',
                                   2);
                     okc_debug.reset_indentation;
                  END IF;
               
                  NULL;
            END;
         END LOOP;
      END IF;
   
      x_line_number := x_line_number + 1;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('6500: Leaving get_next_line_number', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN no_data_found THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('6600: Exiting get_next_line_number:NO_DATA_FOUND Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_line_number := 1;
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('6700: Exiting get_next_line_number:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         -- notify caller of an UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END get_next_line_number;

   -- Start of comments
   --
   -- Procedure Name  : validate_curr_code_rnwd
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_curr_code_rnwd(x_return_status OUT NOCOPY VARCHAR2,
                                     p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_fndv_csr IS
         SELECT 'x'
           FROM fnd_currencies_vl
          WHERE currency_code = p_clev_rec.currency_code_renewed AND
                enabled_flag = 'Y' AND
                SYSDATE BETWEEN nvl(start_date_active, SYSDATE) AND
                nvl(end_date_active, SYSDATE);
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('6800: Entered validate_curr_code_rnwd', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check data is in lookup table only if data is not null
      IF (p_clev_rec.currency_code_renewed <> okc_api.g_miss_char AND
         p_clev_rec.currency_code_renewed IS NOT NULL) THEN
         OPEN l_fndv_csr;
         FETCH l_fndv_csr
            INTO l_dummy_var;
         CLOSE l_fndv_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'currency_code_renewed',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'FND_CURRENCIES');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('6900: Leaving validate_curr_code_rnwd with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('7000: Exiting validate_curr_code_rnwd:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_fndv_csr%ISOPEN THEN
            CLOSE l_fndv_csr;
         END IF;
      
   END validate_curr_code_rnwd;

   -- Procedure Name  : validate_orig_sys_code
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_orig_sys_code(x_return_status OUT NOCOPY VARCHAR2,
                                    p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('7100: Entered validate_orig_sys_code', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key if data exists
      IF (p_clev_rec.orig_system_source_code <> okc_api.g_miss_char AND
         p_clev_rec.orig_system_source_code IS NOT NULL) THEN
         -- Check if the value is a valid code from lookup table
         x_return_status := okc_util.check_lookup_code('OKC_CONTRACT_SOURCES',
                                                       p_clev_rec.orig_system_source_code);
         IF (x_return_status = okc_api.g_ret_sts_error) THEN
            --set error message in message stack
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'ORIG_SYSTEM_SOURCE_CODE');
            RAISE g_exception_halt_validation;
         ELSIF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('7200: Leaving validate_orig_sys_code with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('7300: Exiting validate_orig_sys_code:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_orig_sys_code;

   -- Start of comments
   --
   -- Procedure Name  : validate_dnz_chr_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :

   /*********************** END HAND-CODED ********************************/
   -- Start of comments
   --
   -- Procedure Name  : validate_CONFIG_COMPLETE_YN
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_config_complete_yn(x_return_status OUT NOCOPY VARCHAR2,
                                         p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('7400: Entered validate_config_complete_yn', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.config_complete_yn <> okc_api.g_miss_char AND
         p_clev_rec.config_complete_yn IS NOT NULL) THEN
         IF p_clev_rec.config_complete_yn NOT IN ('Y', 'N') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'config_complete_yn');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('7500: Leaving validate_config_complete_yn with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('7600: Exiting validate_config_complete_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('7700: Exiting validate_config_complete_yn:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_config_complete_yn;

   -------------------------------------------------------------------------------------
   -- Start of comments
   --
   -- Procedure Name  : validate_CONFIG_VALID_YN
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_config_valid_yn(x_return_status OUT NOCOPY VARCHAR2,
                                      p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('7800: Entered validate_config_valid_yn', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.config_valid_yn <> okc_api.g_miss_char AND
         p_clev_rec.config_valid_yn IS NOT NULL) THEN
         IF p_clev_rec.config_valid_yn NOT IN ('Y', 'N') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'config_valid_yn');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('7900: Leaving validate_config_valid_yn with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8000: Exiting validate_config_valid_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8100: Exiting validate_config_valid_yn:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_config_valid_yn;
   --------------------------------------------------------------------------
   -- Start of comments
   --
   -- Procedure Name  : validate_ITEM_TO_PRICE_YN
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_item_to_price_yn(x_return_status OUT NOCOPY VARCHAR2,
                                       p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('8200: Entered validate_item_to_price_yn', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.item_to_price_yn <> okc_api.g_miss_char AND
         p_clev_rec.item_to_price_yn IS NOT NULL) THEN
         IF p_clev_rec.item_to_price_yn NOT IN ('Y', 'N') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'item_to_price_yn');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('8300: Leaving validate_item_to_price_yn with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8400: Exiting validate_item_to_price_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8500: Exiting validate_item_to_price_yn:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_item_to_price_yn;
   --------------------------------------------------------------------------
   -- Start of comments
   --
   -- Procedure Name  : validate_PRICE_BASIS_YN
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_price_basis_yn(x_return_status OUT NOCOPY VARCHAR2,
                                     p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('8600: Entered validate_price_basis_yn', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.price_basis_yn <> okc_api.g_miss_char AND
         p_clev_rec.price_basis_yn IS NOT NULL) THEN
         IF p_clev_rec.price_basis_yn NOT IN ('Y', 'N') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'price_basis_yn');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('8700: Leaving validate_price_basis_yn with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8800: Exiting validate_price_basis_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8900: Exiting validate_price_basis_yn:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_price_basis_yn;
   -----------------------------------------------------------------------------
   -- Start of comments
   --
   -- Procedure Name  : validate_CONFIG_ITEM_TYPE
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_config_item_type(x_return_status OUT NOCOPY VARCHAR2,
                                       p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('9000: Entered validate_config_item_type', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.config_item_type <> okc_api.g_miss_char AND
         p_clev_rec.config_item_type IS NOT NULL) THEN
         IF p_clev_rec.config_item_type NOT IN
            ('TOP_MODEL_LINE', 'TOP_BASE_LINE', 'CONFIG') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'config_item_type');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('9100: Leaving validate_config_item_type with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('9200: Exiting validate_config_item_type:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('9300: Exiting validate_config_item_type:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_config_item_type;
   -----------------------------------------------------------------------------
   -- Start of comments
   --
   -- Procedure Name  : validate_price_list_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_price_list_id(x_return_status OUT NOCOPY VARCHAR2,
                                    p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      -- Bug 2661571 ricagraw
      /*
        Cursor l_chrv_csr Is
           select 'x'
           from QP_PRICE_LISTS_V
           where PRICE_LIST_ID = p_clev_rec.price_list_id;
      */
      -- Bug 2661571 ricagraw
      /*
      ** Bug #3312444, modified the cursor by removing the currency_code
      ** condition. This is not required as a pricelist can be enables in
      ** multiple currencies.
      */
   
      CURSOR l_chrv_csr IS
         SELECT 'x'
           FROM okx_list_headers_v
          WHERE id1 = p_clev_rec.price_list_id AND
                ((status = 'A' AND p_clev_rec.pricing_date IS NULL) OR
                (p_clev_rec.pricing_date IS NOT NULL AND
                p_clev_rec.pricing_date BETWEEN
                nvl(start_date_active, p_clev_rec.pricing_date) AND
                nvl(end_date_active, p_clev_rec.pricing_date)));
      -- and  currency_code = p_clev_rec.currency_code;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('9400: Entered validate_price_list_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.price_list_id <> okc_api.g_miss_num AND
         p_clev_rec.price_list_id IS NOT NULL) THEN
         OPEN l_chrv_csr;
         FETCH l_chrv_csr
            INTO l_dummy_var;
         CLOSE l_chrv_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'PRICE_LIST_ID',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'QP_PRICE_LISTS_V');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('9500: Leaving validate_price_list_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('9600: Exiting validate_price_list_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_chrv_csr%ISOPEN THEN
            CLOSE l_chrv_csr;
         END IF;
      
   END validate_price_list_id;
   -----------------------------------------------------------------------------
   -- Start of comments
   --
   -- Procedure Name  : validate_PRICE_LIST_LINE_ID
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_price_list_line_id(x_return_status OUT NOCOPY VARCHAR2,
                                         p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      /*
        Cursor l_chrv_csr Is
           select 'x'
           from QP_PRICE_LIST_LINES_V
           where PRICE_LIST_LINE_ID = p_clev_rec.price_list_line_id;
      
      Bug No-1993878
      
            */
   
      CURSOR l_chrv_csr IS
         SELECT 'x'
           FROM okx_qp_list_lines_v
          WHERE id1 = p_clev_rec.price_list_line_id;
   
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('9700: Entered validate_price_list_line_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.price_list_line_id <> okc_api.g_miss_num AND
         p_clev_rec.price_list_line_id IS NOT NULL) THEN
         OPEN l_chrv_csr;
         FETCH l_chrv_csr
            INTO l_dummy_var;
         CLOSE l_chrv_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'PRICE_LIST_LINE_ID',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'QP_PRICE_LIST_LINES_V');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('9800: Leaving validate_price_list_line_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('9900: Exiting validate_price_list_line_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_chrv_csr%ISOPEN THEN
            CLOSE l_chrv_csr;
         END IF;
      
   END validate_price_list_line_id;
   -----------------------*
   -- Start of comments
   --
   -- Procedure Name  : validate_conf_top_mod_ln_id
   -- Description     :
   -- Business Rules  :
   -- Parameters      :
   -- Version         : 1.0
   -- End of comments
   PROCEDURE validate_conf_top_mod_ln_id(x_return_status OUT NOCOPY VARCHAR2,
                                         p_clev_rec      IN clev_rec_type) IS
   
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_tml_id_csr IS
         SELECT 'x'
           FROM okc_k_lines_b
          WHERE id = p_clev_rec.config_top_model_line_id AND
                config_item_type = 'TOP_MODEL_LINE';
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('10000: Entered validate_conf_top_mod_ln_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.config_top_model_line_id <> okc_api.g_miss_num AND
         p_clev_rec.config_top_model_line_id IS NOT NULL) THEN
         OPEN l_tml_id_csr;
         FETCH l_tml_id_csr
            INTO l_dummy_var;
         CLOSE l_tml_id_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_no_parent_record,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'CONFIG_TOP_MODEL_LINE_ID',
                                p_token2       => g_child_table_token,
                                p_token2_value => g_view,
                                p_token3       => g_parent_table_token,
                                p_token3_value => 'OKC_K_LINES_V');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('10100: Leaving validate_conf_top_mod_ln_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('10200: Exiting validate_conf_top_mod_ln_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- verify that cursor was closed
         IF l_tml_id_csr%ISOPEN THEN
            CLOSE l_tml_id_csr;
         END IF;
      
   END validate_conf_top_mod_ln_id;
   ----------------------------------------------
   -- Validate_Attributes for: PH_PRICING_TYPE --
   ----------------------------------------------
   PROCEDURE validate_ph_pricing_type(x_return_status OUT NOCOPY VARCHAR2,
                                      p_clev_rec      IN clev_rec_type) IS
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_tmp_csr IS
         SELECT 'x'
           FROM fnd_lookups
          WHERE lookup_code = p_clev_rec.ph_pricing_type AND
                lookup_type = 'OKC_PH_LINE_PRICE_TYPE';
   BEGIN
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('10000: Entered validate_ph_pricing_type', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.ph_pricing_type <> okc_api.g_miss_char AND
         p_clev_rec.ph_pricing_type IS NOT NULL) THEN
         OPEN l_tmp_csr;
         FETCH l_tmp_csr
            INTO l_dummy_var;
         CLOSE l_tmp_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'ph_pricing_type');
            x_return_status := okc_api.g_ret_sts_error;
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('10100: Leaving validate_ph_pricing_type with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8400: Exiting validate_item_to_price_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('10200: Exiting validate_ph_pricing_type:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
   END validate_ph_pricing_type;
   ---------------------------------------------------
   -- Validate_Attributes for: PH_PRICE_BREAK_BASIS --
   ---------------------------------------------------
   PROCEDURE validate_ph_price_break_basis(x_return_status OUT NOCOPY VARCHAR2,
                                           p_clev_rec      IN clev_rec_type) IS
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_tmp_csr IS
         SELECT 'x'
           FROM fnd_lookups
          WHERE lookup_code = p_clev_rec.ph_price_break_basis AND
                lookup_type = 'OKC_PH_PRICE_BREAK_BASIS';
   BEGIN
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('10000: Entered validate_ph_price_break_basis', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.ph_price_break_basis <> okc_api.g_miss_char AND
         p_clev_rec.ph_price_break_basis IS NOT NULL) THEN
         OPEN l_tmp_csr;
         FETCH l_tmp_csr
            INTO l_dummy_var;
         CLOSE l_tmp_csr;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'ph_price_break_basis');
            x_return_status := okc_api.g_ret_sts_error;
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('10100: Leaving validate_ph_price_break_basis with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8400: Exiting validate_item_to_price_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('10200: Exiting validate_ph_price_break_basis:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
   END validate_ph_price_break_basis;
   -------------------------------------------------
   -- Validate_Attributes for: PH_QP_REFERENCE_ID --
   -------------------------------------------------
   PROCEDURE validate_ph_qp_reference_id(x_return_status OUT NOCOPY VARCHAR2,
                                         p_clev_rec      IN clev_rec_type) IS
      l_dummy_var VARCHAR2(1) := '?';
      CURSOR l_tmp_1_csr IS
         SELECT 'x'
           FROM qp_list_headers_b
          WHERE list_header_id = p_clev_rec.ph_qp_reference_id;
      CURSOR l_tmp_2_csr IS
         SELECT 'x'
           FROM qp_list_lines
          WHERE list_line_id = p_clev_rec.ph_qp_reference_id;
   BEGIN
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('10000: Entered validate_ph_qp_reference_id', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- enforce foreign key, if data exists
      IF (p_clev_rec.ph_qp_reference_id <> okc_api.g_miss_num AND
         p_clev_rec.ph_qp_reference_id IS NOT NULL) THEN
         IF p_clev_rec.cle_id IS NULL THEN
            -- top level line should point to QP_LIST_HEADERS
            OPEN l_tmp_1_csr;
            FETCH l_tmp_1_csr
               INTO l_dummy_var;
            CLOSE l_tmp_1_csr;
         ELSE
            -- subline should point to QP_LIST_LINES
            OPEN l_tmp_2_csr;
            FETCH l_tmp_2_csr
               INTO l_dummy_var;
            CLOSE l_tmp_2_csr;
         END IF;
      
         -- if l_dummy_var still set to default, data was not found
         IF (l_dummy_var = '?') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'ph_qp_reference_id');
            x_return_status := okc_api.g_ret_sts_error;
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('10100: Leaving validate_ph_qp_reference_id with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8400: Exiting validate_item_to_price_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('10200: Exiting validate_ph_qp_reference_id:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         x_return_status := okc_api.g_ret_sts_unexp_error;
   END validate_ph_qp_reference_id;
   -------------------------------------------------
   -- Validate_Attributes for: PH_ENFORCE_PRICE_LIST_YN --
   -------------------------------------------------
   PROCEDURE validate_ph_enforce_price_list(x_return_status OUT NOCOPY VARCHAR2,
                                            p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('8200: Entered validate_ph_enforce_price_list_yn',
                       2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.ph_enforce_price_list_yn <> okc_api.g_miss_char AND
         p_clev_rec.ph_enforce_price_list_yn IS NOT NULL) THEN
         IF p_clev_rec.ph_enforce_price_list_yn NOT IN ('Y', 'N') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'ph_enforce_price_list_yn');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('8300: Leaving validate_ph_enforce_price_list_yn with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8400: Exiting validate_ph_enforce_price_list_yn:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8500: Exiting validate_ph_enforce_price_list_yn:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_ph_enforce_price_list;
   -------------------------------------------------
   -- Validate_Attributes for: PH_INTEGRATED_WITH_QP --
   -------------------------------------------------
   PROCEDURE validate_ph_integrated_with_qp(x_return_status OUT NOCOPY VARCHAR2,
                                            p_clev_rec      IN clev_rec_type) IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('8200: Entered validate_ph_integrated_with_qp', 2);
      END IF;
   
      -- initialize return status
      x_return_status := okc_api.g_ret_sts_success;
   
      -- check that data exists
      IF (p_clev_rec.ph_integrated_with_qp <> okc_api.g_miss_char AND
         p_clev_rec.ph_integrated_with_qp IS NOT NULL) THEN
         IF p_clev_rec.ph_integrated_with_qp NOT IN ('Y', 'N') THEN
            okc_api.set_message(p_app_name     => g_app_name,
                                p_msg_name     => g_invalid_value,
                                p_token1       => g_col_name_token,
                                p_token1_value => 'ph_integrated_with_qp');
            -- notify caller of an error
            x_return_status := okc_api.g_ret_sts_error;
         
            -- halt validation
            RAISE g_exception_halt_validation;
         END IF;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('8300: Leaving validate_ph_integrated_with_qp with return status ' ||
                       x_return_status,
                       2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN g_exception_halt_validation THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8400: Exiting validate_ph_integrated_with_qp:G_EXCEPTION_HALT_VALIDATION Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- no processing necessary; validation can continue with next column
         NULL;
      
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('8500: Exiting validate_ph_integrated_with_qp:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
   END validate_ph_integrated_with_qp;
   ---------------------------------------------------------------------------
   -- FUNCTION get_seq_id
   ---------------------------------------------------------------------------
   FUNCTION get_seq_id RETURN NUMBER IS
   BEGIN
   
      RETURN(okc_p_util.raw_to_number(sys_guid()));
   
   END get_seq_id;

   ---------------------------------------------------------------------------
   -- PROCEDURE qc
   ---------------------------------------------------------------------------
   PROCEDURE qc IS
   BEGIN
   
      NULL;
   
   END qc;

   ---------------------------------------------------------------------------
   -- PROCEDURE change_version
   ---------------------------------------------------------------------------
   PROCEDURE change_version IS
   BEGIN
   
      NULL;
   
   END change_version;

   ---------------------------------------------------------------------------
   -- PROCEDURE api_copy
   ---------------------------------------------------------------------------
   PROCEDURE api_copy IS
   BEGIN
   
      NULL;
   
   END api_copy;

   ---------------------------------------------------------------------------
   -- PROCEDURE add_language
   ---------------------------------------------------------------------------
   PROCEDURE add_language IS
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('10700: Entered add_language', 2);
      END IF;
   
      /* Mar/19/03 requested by Ric Ginsberg */
      /* The following delete and update statements are commented out */
      /* as a quick workaround to fix the time-consuming table handler issue */
      /* Eventually we'll need to turn them into a separate fix_language procedure */
      /*
      
          DELETE FROM OKC_K_LINES_TL T
           WHERE NOT EXISTS (
              SELECT NULL
                FROM OKC_K_LINES_B B
               WHERE B.ID = T.ID
              );
      
          UPDATE OKC_K_LINES_TL T SET (
              NAME,
              COMMENTS,
              ITEM_DESCRIPTION,
              OKE_BOE_DESCRIPTION,
              COGNOMEN,
              BLOCK23TEXT) = (SELECT
                                        B.NAME,
                                        B.COMMENTS,
                                        B.ITEM_DESCRIPTION,
                    B.OKE_BOE_DESCRIPTION,
                    B.COGNOMEN,
                                        B.BLOCK23TEXT
                                      FROM OKC_K_LINES_TL B
                                     WHERE B.ID = T.ID
                                       AND B.LANGUAGE = T.SOURCE_LANG)
            WHERE (
                    T.ID,
                    T.LANGUAGE)
                IN (SELECT
                        SUBT.ID,
                        SUBT.LANGUAGE
                      FROM OKC_K_LINES_TL SUBB, OKC_K_LINES_TL SUBT
                     WHERE SUBB.ID = SUBT.ID
                       AND SUBB.LANGUAGE = SUBT.SOURCE_LANG
                       AND (SUBB.NAME <> SUBT.NAME
                            OR SUBB.COMMENTS <> SUBT.COMMENTS
                            OR SUBB.ITEM_DESCRIPTION <> SUBT.ITEM_DESCRIPTION
                            OR SUBB.OKE_BOE_DESCRIPTION <> SUBT.OKE_BOE_DESCRIPTION
                            OR SUBB.COGNOMEN <> SUBT.COGNOMEN
                            OR SUBB.BLOCK23TEXT <> SUBT.BLOCK23TEXT
                            OR (SUBB.NAME IS NULL AND SUBT.NAME IS NOT NULL)
                            OR (SUBB.NAME IS NOT NULL AND SUBT.NAME IS NULL)
                            OR (SUBB.COMMENTS IS NULL AND SUBT.COMMENTS IS NOT NULL)
                            OR (SUBB.COMMENTS IS NOT NULL AND SUBT.COMMENTS IS NULL)
                            OR (SUBB.ITEM_DESCRIPTION IS NULL AND SUBT.ITEM_DESCRIPTION IS NOT NULL)
                            OR (SUBB.ITEM_DESCRIPTION IS NOT NULL AND SUBT.ITEM_DESCRIPTION IS NULL)
                            OR (SUBB.OKE_BOE_DESCRIPTION IS NULL AND SUBT.OKE_BOE_DESCRIPTION IS NOT NULL)
                            OR (SUBB.OKE_BOE_DESCRIPTION IS NOT NULL AND SUBT.OKE_BOE_DESCRIPTION IS NULL)
                            OR (SUBB.COGNOMEN IS NULL AND SUBT.COGNOMEN IS NOT NULL)
                            OR (SUBB.COGNOMEN IS NOT NULL AND SUBT.COGNOMEN IS NULL)
                            OR (SUBB.BLOCK23TEXT IS NULL AND SUBT.BLOCK23TEXT IS NOT NULL)
                            OR (SUBB.BLOCK23TEXT IS NOT NULL AND SUBT.BLOCK23TEXT IS NULL)
                    ));
      */
      /* Modifying Insert as per performance guidelines given in bug 3723874 */
      INSERT /*+ append parallel(tt) */
      INTO okc_k_lines_tl tt
         (id,
          LANGUAGE,
          source_lang,
          sfwt_flag,
          NAME,
          comments,
          item_description,
          oke_boe_description,
          cognomen,
          block23text,
          created_by,
          creation_date,
          last_updated_by,
          last_update_date,
          last_update_login)
         SELECT /*+ parallel(v) parallel(t) use_nl(t)  */
          v.*
           FROM (SELECT /*+ no_merge ordered parallel(b) */
                  b.id,
                  l.language_code,
                  b.source_lang,
                  b.sfwt_flag,
                  b.NAME,
                  b.comments,
                  b.item_description,
                  b.oke_boe_description,
                  b.cognomen,
                  b.block23text,
                  b.created_by,
                  b.creation_date,
                  b.last_updated_by,
                  b.last_update_date,
                  b.last_update_login
                   FROM okc_k_lines_tl b, fnd_languages l
                  WHERE l.installed_flag IN ('I', 'B') AND
                        b.LANGUAGE = userenv('LANG')) v,
                okc_k_lines_tl t
          WHERE t.id(+) = v.id AND
                t.LANGUAGE(+) = v.language_code AND
                t.id IS NULL;
   
      /* Commenting delete and update for bug 3723874 */
      /*
          DELETE FROM OKC_K_LINES_TLH T
           WHERE NOT EXISTS (
              SELECT NULL
                FROM OKC_K_LINES_BH B
               WHERE B.ID = T.ID
               AND T.MAJOR_VERSION = B.MAJOR_VERSION
              );
      
          UPDATE OKC_K_LINES_TLH T SET (
              NAME,
              COMMENTS,
              ITEM_DESCRIPTION,
              OKE_BOE_DESCRIPTION,
              COGNOMEN,
              BLOCK23TEXT) = (SELECT
                                        B.NAME,
                                        B.COMMENTS,
                                        B.ITEM_DESCRIPTION,
                                        B.OKE_BOE_DESCRIPTION,
                                        B.COGNOMEN,
                                        B.BLOCK23TEXT
                                      FROM OKC_K_LINES_TLH B
                                     WHERE B.ID = T.ID
                                      AND B.MAJOR_VERSION = T.MAJOR_VERSION
                                       AND B.LANGUAGE = T.SOURCE_LANG)
            WHERE (
                    T.ID,
                    T.MAJOR_VERSION,
                    T.LANGUAGE)
                IN (SELECT
                        SUBT.ID,
                        SUBT.MAJOR_VERSION,
                        SUBT.LANGUAGE
                      FROM OKC_K_LINES_TLH SUBB, OKC_K_LINES_TLH SUBT
                     WHERE SUBB.ID = SUBT.ID
                       AND SUBB.MAJOR_VERSION = SUBT.MAJOR_VERSION
                       AND SUBB.LANGUAGE = SUBT.SOURCE_LANG
                       AND (SUBB.NAME <> SUBT.NAME
                            OR SUBB.COMMENTS <> SUBT.COMMENTS
                            OR SUBB.ITEM_DESCRIPTION <> SUBT.ITEM_DESCRIPTION
                            OR SUBB.OKE_BOE_DESCRIPTION <> SUBT.OKE_BOE_DESCRIPTION
                            OR SUBB.COGNOMEN <> SUBT.COGNOMEN
                            OR SUBB.BLOCK23TEXT <> SUBT.BLOCK23TEXT
                            OR (SUBB.NAME IS NULL AND SUBT.NAME IS NOT NULL)
                            OR (SUBB.NAME IS NOT NULL AND SUBT.NAME IS NULL)
                            OR (SUBB.COMMENTS IS NULL AND SUBT.COMMENTS IS NOT NULL)
                            OR (SUBB.COMMENTS IS NOT NULL AND SUBT.COMMENTS IS NULL)
                            OR (SUBB.ITEM_DESCRIPTION IS NULL AND SUBT.ITEM_DESCRIPTION IS NOT NULL)
                            OR (SUBB.ITEM_DESCRIPTION IS NOT NULL AND SUBT.ITEM_DESCRIPTION IS NULL)
                            OR (SUBB.OKE_BOE_DESCRIPTION IS NULL AND SUBT.OKE_BOE_DESCRIPTION IS NOT NULL)
                            OR (SUBB.OKE_BOE_DESCRIPTION IS NOT NULL AND SUBT.OKE_BOE_DESCRIPTION IS NULL)
                            OR (SUBB.COGNOMEN IS NULL AND SUBT.COGNOMEN IS NOT NULL)
                            OR (SUBB.COGNOMEN IS NOT NULL AND SUBT.COGNOMEN IS NULL)
                            OR (SUBB.BLOCK23TEXT IS NULL AND SUBT.BLOCK23TEXT IS NOT NULL)
                            OR (SUBB.BLOCK23TEXT IS NOT NULL AND SUBT.BLOCK23TEXT IS NULL)
                    ));
      */
      /* Modifying Insert as per performance guidelines given in bug 3723874 */
      INSERT /*+ append parallel(tt) */
      INTO okc_k_lines_tlh tt
         (id,
          LANGUAGE,
          major_version,
          source_lang,
          sfwt_flag,
          NAME,
          comments,
          item_description,
          oke_boe_description,
          cognomen,
          block23text,
          created_by,
          creation_date,
          last_updated_by,
          
          last_update_date,
          last_update_login)
         SELECT /*+ parallel(v) parallel(t) use_nl(t)  */
          v.*
           FROM (SELECT /*+ no_merge ordered parallel(b) */
                  b.id,
                  l.language_code,
                  b.major_version,
                  b.source_lang,
                  b.sfwt_flag,
                  b.NAME,
                  b.comments,
                  b.item_description,
                  b.oke_boe_description,
                  b.cognomen,
                  b.block23text,
                  b.created_by,
                  b.creation_date,
                  b.last_updated_by,
                  b.last_update_date,
                  b.last_update_login
                   FROM okc_k_lines_tlh b, fnd_languages l
                  WHERE l.installed_flag IN ('I', 'B') AND
                        b.LANGUAGE = userenv('LANG')) v,
                okc_k_lines_tlh t
          WHERE t.id(+) = v.id AND
                t.LANGUAGE(+) = v.language_code AND
                t.major_version(+) = v.major_version AND
                t.id IS NULL;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('10750: Leaving  add_language ', 2);
         okc_debug.reset_indentation;
      END IF;
   
   END add_language;

   ---------------------------------------------------------------------------
   -- FUNCTION get_rec for: OKC_K_LINES_B
   ---------------------------------------------------------------------------
   FUNCTION get_rec(p_cle_rec       IN cle_rec_type,
                    x_no_data_found OUT NOCOPY BOOLEAN) RETURN cle_rec_type IS
      CURSOR cle_pk_csr(p_id IN NUMBER) IS
         SELECT id,
                line_number,
                chr_id,
                cle_id,
                dnz_chr_id,
                display_sequence,
                sts_code,
                trn_code,
                lse_id,
                exception_yn,
                object_version_number,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                hidden_ind,
                price_unit,
                price_unit_percent,
                price_negotiated,
                price_negotiated_renewed,
                price_level_ind,
                invoice_line_level_ind,
                dpas_rating,
                template_used,
                price_type,
                currency_code,
                currency_code_renewed,
                last_update_login,
                date_terminated,
                start_date,
                end_date,
                date_renewed,
                upg_orig_system_ref,
                upg_orig_system_ref_id,
                orig_system_source_code,
                orig_system_id1,
                orig_system_reference1,
                request_id,
                program_application_id,
                program_id,
                program_update_date,
                price_list_id,
                pricing_date,
                price_list_line_id,
                line_list_price,
                item_to_price_yn,
                price_basis_yn,
                config_header_id,
                config_revision_number,
                config_complete_yn,
                config_valid_yn,
                config_top_model_line_id,
                config_item_type,
                config_item_id,
                attribute_category,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                attribute6,
                attribute7,
                attribute8,
                attribute9,
                attribute10,
                attribute11,
                attribute12,
                attribute13,
                attribute14,
                attribute15,
                service_item_yn,
                --new columns for price hold
                ph_pricing_type,
                ph_price_break_basis,
                ph_min_qty,
                ph_min_amt,
                ph_qp_reference_id,
                ph_value,
                ph_enforce_price_list_yn,
                ph_adjustment,
                ph_integrated_with_qp,
                -- new colums to replace rules
                cust_acct_id,
                bill_to_site_use_id,
                inv_rule_id,
                line_renewal_type_code,
                ship_to_site_use_id,
                payment_term_id,
                --NPALEPU on 30-JUN-2005 added new column for Annualized Amounts project
                annualized_factor,
                --END NPALEPU-
                date_cancelled, -- New columns for Line Level Cancellation
                --canc_reason_code,
                term_cancel_source,
                cancelled_amount,
                payment_instruction_type --added by mchoudha 22-JUL
           FROM okc_k_lines_b
          WHERE okc_k_lines_b.id = p_id;
      l_cle_pk  cle_pk_csr%ROWTYPE;
      l_cle_rec cle_rec_type;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('10800: Entered get_rec', 2);
      END IF;
   
      x_no_data_found := TRUE;
      -- Get current database values
      OPEN cle_pk_csr(p_cle_rec.id);
      FETCH cle_pk_csr
         INTO l_cle_rec.id, l_cle_rec.line_number, l_cle_rec.chr_id, l_cle_rec.cle_id, l_cle_rec.dnz_chr_id, l_cle_rec.display_sequence, l_cle_rec.sts_code, l_cle_rec.trn_code, l_cle_rec.lse_id, l_cle_rec.exception_yn, l_cle_rec.object_version_number, l_cle_rec.created_by, l_cle_rec.creation_date, l_cle_rec.last_updated_by, l_cle_rec.last_update_date, l_cle_rec.hidden_ind, l_cle_rec.price_unit, l_cle_rec.price_unit_percent, l_cle_rec.price_negotiated, l_cle_rec.price_negotiated_renewed, l_cle_rec.price_level_ind, l_cle_rec.invoice_line_level_ind, l_cle_rec.dpas_rating, l_cle_rec.template_used, l_cle_rec.price_type, l_cle_rec.currency_code, l_cle_rec.currency_code_renewed, l_cle_rec.last_update_login, l_cle_rec.date_terminated, l_cle_rec.start_date, l_cle_rec.end_date, l_cle_rec.date_renewed, l_cle_rec.upg_orig_system_ref, l_cle_rec.upg_orig_system_ref_id, l_cle_rec.orig_system_source_code, l_cle_rec.orig_system_id1, l_cle_rec.orig_system_reference1, l_cle_rec.request_id, l_cle_rec.program_application_id, l_cle_rec.program_id, l_cle_rec.program_update_date, l_cle_rec.price_list_id, l_cle_rec.pricing_date, l_cle_rec.price_list_line_id, l_cle_rec.line_list_price, l_cle_rec.item_to_price_yn, l_cle_rec.price_basis_yn, l_cle_rec.config_header_id, l_cle_rec.config_revision_number, l_cle_rec.config_complete_yn, l_cle_rec.config_valid_yn, l_cle_rec.config_top_model_line_id, l_cle_rec.config_item_type, l_cle_rec.config_item_id, l_cle_rec.attribute_category, l_cle_rec.attribute1, l_cle_rec.attribute2, l_cle_rec.attribute3, l_cle_rec.attribute4, l_cle_rec.attribute5, l_cle_rec.attribute6, l_cle_rec.attribute7, l_cle_rec.attribute8, l_cle_rec.attribute9, l_cle_rec.attribute10, l_cle_rec.attribute11, l_cle_rec.attribute12, l_cle_rec.attribute13, l_cle_rec.attribute14, l_cle_rec.attribute15, l_cle_rec.service_item_yn,
      --new columns for price hold
      l_cle_rec.ph_pricing_type, l_cle_rec.ph_price_break_basis, l_cle_rec.ph_min_qty, l_cle_rec.ph_min_amt, l_cle_rec.ph_qp_reference_id, l_cle_rec.ph_value, l_cle_rec.ph_enforce_price_list_yn, l_cle_rec.ph_adjustment, l_cle_rec.ph_integrated_with_qp,
      -- new columns to  replace rules
      l_cle_rec.cust_acct_id, l_cle_rec.bill_to_site_use_id, l_cle_rec.inv_rule_id, l_cle_rec.line_renewal_type_code, l_cle_rec.ship_to_site_use_id, l_cle_rec.payment_term_id,
      --NPALEPU on 24-JUN-2005 added new column for Annualized Amounts project
      l_cle_rec.annualized_factor,
      --END NPALEPU
      l_cle_rec.date_cancelled,
      --l_cle_rec.canc_reason_code,
      l_cle_rec.term_cancel_source, l_cle_rec.cancelled_amount, l_cle_rec.payment_instruction_type; --added by mchoudha 22-JUL
      x_no_data_found := cle_pk_csr%NOTFOUND;
      CLOSE cle_pk_csr;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('10850: Leaving  Fn  get_rec ', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN(l_cle_rec);
   
   END get_rec;

   FUNCTION get_rec(p_cle_rec IN cle_rec_type) RETURN cle_rec_type IS
      l_row_notfound BOOLEAN := TRUE;
   BEGIN
   
      RETURN(get_rec(p_cle_rec, l_row_notfound));
   
   END get_rec;
   ---------------------------------------------------------------------------
   -- FUNCTION get_rec for: OKC_K_LINES_TL
   ---------------------------------------------------------------------------
   FUNCTION get_rec(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                    x_no_data_found      OUT NOCOPY BOOLEAN)
      RETURN okc_k_lines_tl_rec_type IS
      CURSOR cle_pktl_csr(p_id IN NUMBER, p_language IN VARCHAR2) IS
         SELECT id,
                LANGUAGE,
                source_lang,
                sfwt_flag,
                NAME,
                comments,
                item_description,
                oke_boe_description,
                cognomen,
                block23text,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                last_update_login
           FROM okc_k_lines_tl
          WHERE okc_k_lines_tl.id = p_id AND
                okc_k_lines_tl.LANGUAGE = p_language;
      l_cle_pktl           cle_pktl_csr%ROWTYPE;
      l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('11000: Entered get_rec', 2);
      END IF;
   
      x_no_data_found := TRUE;
      -- Get current database values
      OPEN cle_pktl_csr(p_okc_k_lines_tl_rec.id,
                        p_okc_k_lines_tl_rec.LANGUAGE);
      FETCH cle_pktl_csr
         INTO l_okc_k_lines_tl_rec.id, l_okc_k_lines_tl_rec.LANGUAGE, l_okc_k_lines_tl_rec.source_lang, l_okc_k_lines_tl_rec.sfwt_flag, l_okc_k_lines_tl_rec.NAME, l_okc_k_lines_tl_rec.comments, l_okc_k_lines_tl_rec.item_description, l_okc_k_lines_tl_rec.oke_boe_description, l_okc_k_lines_tl_rec.cognomen, l_okc_k_lines_tl_rec.block23text, l_okc_k_lines_tl_rec.created_by, l_okc_k_lines_tl_rec.creation_date, l_okc_k_lines_tl_rec.last_updated_by, l_okc_k_lines_tl_rec.last_update_date, l_okc_k_lines_tl_rec.last_update_login;
      x_no_data_found := cle_pktl_csr%NOTFOUND;
      CLOSE cle_pktl_csr;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('11050: Leaving  Fn  get_rec ', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN(l_okc_k_lines_tl_rec);
   
   END get_rec;

   FUNCTION get_rec(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type)
      RETURN okc_k_lines_tl_rec_type IS
      l_row_notfound BOOLEAN := TRUE;
   BEGIN
   
      RETURN(get_rec(p_okc_k_lines_tl_rec, l_row_notfound));
   
   END get_rec;
   ---------------------------------------------------------------------------
   -- FUNCTION get_rec for: OKC_K_LINES_V
   ---------------------------------------------------------------------------
   FUNCTION get_rec(p_clev_rec      IN clev_rec_type,
                    x_no_data_found OUT NOCOPY BOOLEAN) RETURN clev_rec_type IS
      CURSOR okc_clev_pk_csr(p_id IN NUMBER) IS
         SELECT id,
                object_version_number,
                sfwt_flag,
                chr_id,
                cle_id,
                lse_id,
                line_number,
                sts_code,
                display_sequence,
                trn_code,
                dnz_chr_id,
                comments,
                item_description,
                oke_boe_description,
                cognomen,
                hidden_ind,
                price_unit,
                price_unit_percent,
                price_negotiated,
                price_negotiated_renewed,
                price_level_ind,
                invoice_line_level_ind,
                dpas_rating,
                block23text,
                exception_yn,
                template_used,
                date_terminated,
                NAME,
                start_date,
                end_date,
                date_renewed,
                upg_orig_system_ref,
                upg_orig_system_ref_id,
                orig_system_source_code,
                orig_system_id1,
                orig_system_reference1,
                request_id,
                program_application_id,
                program_id,
                program_update_date,
                price_list_id,
                pricing_date,
                price_list_line_id,
                line_list_price,
                item_to_price_yn,
                price_basis_yn,
                config_header_id,
                config_revision_number,
                config_complete_yn,
                config_valid_yn,
                config_top_model_line_id,
                config_item_type,
                config_item_id,
                attribute_category,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                attribute6,
                attribute7,
                attribute8,
                attribute9,
                attribute10,
                attribute11,
                attribute12,
                attribute13,
                attribute14,
                attribute15,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                price_type,
                currency_code,
                currency_code_renewed,
                last_update_login,
                service_item_yn,
                --new columns for price hold
                ph_pricing_type,
                ph_price_break_basis,
                ph_min_qty,
                ph_min_amt,
                ph_qp_reference_id,
                ph_value,
                ph_enforce_price_list_yn,
                ph_adjustment,
                ph_integrated_with_qp,
                --new columns to replace rules
                cust_acct_id,
                bill_to_site_use_id,
                inv_rule_id,
                line_renewal_type_code,
                ship_to_site_use_id,
                payment_term_id,
                date_cancelled,
                --CANC_REASON_CODE,
                term_cancel_source,
                cancelled_amount,
                --added by mchoudha 22-JUL
                annualized_factor,
                payment_instruction_type
           FROM okc_k_lines_v
          WHERE okc_k_lines_v.id = p_id;
      l_okc_clev_pk okc_clev_pk_csr%ROWTYPE;
      l_clev_rec    clev_rec_type;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('11200: Entered get_rec', 2);
      END IF;
   
      x_no_data_found := TRUE;
      -- Get current database values
      OPEN okc_clev_pk_csr(p_clev_rec.id);
      FETCH okc_clev_pk_csr
         INTO l_clev_rec.id, l_clev_rec.object_version_number, l_clev_rec.sfwt_flag, l_clev_rec.chr_id, l_clev_rec.cle_id, l_clev_rec.lse_id, l_clev_rec.line_number, l_clev_rec.sts_code, l_clev_rec.display_sequence, l_clev_rec.trn_code, l_clev_rec.dnz_chr_id, l_clev_rec.comments, l_clev_rec.item_description, l_clev_rec.oke_boe_description, l_clev_rec.cognomen, l_clev_rec.hidden_ind, l_clev_rec.price_unit, l_clev_rec.price_unit_percent, l_clev_rec.price_negotiated, l_clev_rec.price_negotiated_renewed, l_clev_rec.price_level_ind, l_clev_rec.invoice_line_level_ind, l_clev_rec.dpas_rating, l_clev_rec.block23text, l_clev_rec.exception_yn, l_clev_rec.template_used, l_clev_rec.date_terminated, l_clev_rec.NAME, l_clev_rec.start_date, l_clev_rec.end_date, l_clev_rec.date_renewed, l_clev_rec.upg_orig_system_ref, l_clev_rec.upg_orig_system_ref_id, l_clev_rec.orig_system_source_code, l_clev_rec.orig_system_id1, l_clev_rec.orig_system_reference1, l_clev_rec.request_id, l_clev_rec.program_application_id, l_clev_rec.program_id, l_clev_rec.program_update_date, l_clev_rec.price_list_id, l_clev_rec.pricing_date, l_clev_rec.price_list_line_id, l_clev_rec.line_list_price, l_clev_rec.item_to_price_yn, l_clev_rec.price_basis_yn, l_clev_rec.config_header_id, l_clev_rec.config_revision_number, l_clev_rec.config_complete_yn, l_clev_rec.config_valid_yn, l_clev_rec.config_top_model_line_id, l_clev_rec.config_item_type, l_clev_rec.config_item_id, l_clev_rec.attribute_category, l_clev_rec.attribute1, l_clev_rec.attribute2, l_clev_rec.attribute3, l_clev_rec.attribute4, l_clev_rec.attribute5, l_clev_rec.attribute6, l_clev_rec.attribute7, l_clev_rec.attribute8, l_clev_rec.attribute9, l_clev_rec.attribute10, l_clev_rec.attribute11, l_clev_rec.attribute12, l_clev_rec.attribute13, l_clev_rec.attribute14, l_clev_rec.attribute15, l_clev_rec.created_by, l_clev_rec.creation_date, l_clev_rec.last_updated_by, l_clev_rec.last_update_date, l_clev_rec.price_type, l_clev_rec.currency_code, l_clev_rec.currency_code_renewed, l_clev_rec.last_update_login, l_clev_rec.service_item_yn,
      -- new columns for price hold
      l_clev_rec.ph_pricing_type, l_clev_rec.ph_price_break_basis, l_clev_rec.ph_min_qty, l_clev_rec.ph_min_amt, l_clev_rec.ph_qp_reference_id, l_clev_rec.ph_value, l_clev_rec.ph_enforce_price_list_yn, l_clev_rec.ph_adjustment, l_clev_rec.ph_integrated_with_qp,
      -- new columns to  replace rules
      l_clev_rec.cust_acct_id, l_clev_rec.bill_to_site_use_id, l_clev_rec.inv_rule_id, l_clev_rec.line_renewal_type_code, l_clev_rec.ship_to_site_use_id, l_clev_rec.payment_term_id, l_clev_rec.date_cancelled,
      --l_clev_rec.canc_reason_code,
      l_clev_rec.term_cancel_source, l_clev_rec.cancelled_amount,
      --added by mchoudha 22-JUL
      l_clev_rec.annualized_factor, l_clev_rec.payment_instruction_type;
      x_no_data_found := okc_clev_pk_csr%NOTFOUND;
      CLOSE okc_clev_pk_csr;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('11250: Leaving  Fn  get_rec ', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN(l_clev_rec);
   
   END get_rec;

   FUNCTION get_rec(p_clev_rec IN clev_rec_type) RETURN clev_rec_type IS
      l_row_notfound BOOLEAN := TRUE;
   BEGIN
   
      RETURN(get_rec(p_clev_rec, l_row_notfound));
   
   END get_rec;

   ---------------------------------------------------
   -- FUNCTION null_out_defaults for: OKC_K_LINES_V --
   ---------------------------------------------------
   FUNCTION null_out_defaults(p_clev_rec IN clev_rec_type)
      RETURN clev_rec_type IS
      l_clev_rec clev_rec_type := p_clev_rec;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('11400: Entered null_out_defaults', 2);
      END IF;
   
      IF (l_clev_rec.object_version_number = okc_api.g_miss_num) THEN
         l_clev_rec.object_version_number := NULL;
      END IF;
      IF (l_clev_rec.sfwt_flag = okc_api.g_miss_char) THEN
         l_clev_rec.sfwt_flag := NULL;
      END IF;
      IF (l_clev_rec.chr_id = okc_api.g_miss_num) THEN
         l_clev_rec.chr_id := NULL;
      END IF;
      IF (l_clev_rec.cle_id = okc_api.g_miss_num) THEN
         l_clev_rec.cle_id := NULL;
      END IF;
      IF (l_clev_rec.lse_id = okc_api.g_miss_num) THEN
         l_clev_rec.lse_id := NULL;
      END IF;
      IF (l_clev_rec.line_number = okc_api.g_miss_char) THEN
         l_clev_rec.line_number := NULL;
      END IF;
      IF (l_clev_rec.sts_code = okc_api.g_miss_char) THEN
         l_clev_rec.sts_code := NULL;
      END IF;
      IF (l_clev_rec.display_sequence = okc_api.g_miss_num) THEN
         l_clev_rec.display_sequence := NULL;
      END IF;
      IF (l_clev_rec.trn_code = okc_api.g_miss_char) THEN
         l_clev_rec.trn_code := NULL;
      END IF;
      IF (l_clev_rec.dnz_chr_id = okc_api.g_miss_num) THEN
         l_clev_rec.dnz_chr_id := NULL;
      END IF;
      IF (l_clev_rec.comments = okc_api.g_miss_char) THEN
         l_clev_rec.comments := NULL;
      END IF;
      IF (l_clev_rec.item_description = okc_api.g_miss_char) THEN
         l_clev_rec.item_description := NULL;
      END IF;
      IF (l_clev_rec.oke_boe_description = okc_api.g_miss_char) THEN
         l_clev_rec.oke_boe_description := NULL;
      END IF;
      IF (l_clev_rec.cognomen = okc_api.g_miss_char) THEN
         l_clev_rec.cognomen := NULL;
      END IF;
      IF (l_clev_rec.hidden_ind = okc_api.g_miss_char) THEN
         l_clev_rec.hidden_ind := NULL;
      END IF;
      IF (l_clev_rec.price_unit = okc_api.g_miss_num) THEN
         l_clev_rec.price_unit := NULL;
      END IF;
      IF (l_clev_rec.price_unit_percent = okc_api.g_miss_num) THEN
         l_clev_rec.price_unit_percent := NULL;
      END IF;
      IF (l_clev_rec.price_negotiated = okc_api.g_miss_num) THEN
         l_clev_rec.price_negotiated := NULL;
      END IF;
      IF (l_clev_rec.price_negotiated_renewed = okc_api.g_miss_num) THEN
         l_clev_rec.price_negotiated_renewed := NULL;
      END IF;
      IF (l_clev_rec.price_level_ind = okc_api.g_miss_char) THEN
         l_clev_rec.price_level_ind := NULL;
      END IF;
      IF (l_clev_rec.invoice_line_level_ind = okc_api.g_miss_char) THEN
         l_clev_rec.invoice_line_level_ind := NULL;
      END IF;
      IF (l_clev_rec.dpas_rating = okc_api.g_miss_char) THEN
         l_clev_rec.dpas_rating := NULL;
      END IF;
      IF (l_clev_rec.block23text = okc_api.g_miss_char) THEN
         l_clev_rec.block23text := NULL;
      END IF;
      IF (l_clev_rec.exception_yn = okc_api.g_miss_char) THEN
         l_clev_rec.exception_yn := NULL;
      END IF;
      IF (l_clev_rec.template_used = okc_api.g_miss_char) THEN
         l_clev_rec.template_used := NULL;
      END IF;
      IF (l_clev_rec.date_terminated = okc_api.g_miss_date) THEN
         l_clev_rec.date_terminated := NULL;
      END IF;
      IF (l_clev_rec.NAME = okc_api.g_miss_char) THEN
         l_clev_rec.NAME := NULL;
      END IF;
      IF (l_clev_rec.start_date = okc_api.g_miss_date) THEN
         l_clev_rec.start_date := NULL;
      END IF;
      IF (l_clev_rec.end_date = okc_api.g_miss_date) THEN
         l_clev_rec.end_date := NULL;
      END IF;
      IF (l_clev_rec.date_renewed = okc_api.g_miss_date) THEN
         l_clev_rec.date_renewed := NULL;
      END IF;
      IF (l_clev_rec.upg_orig_system_ref = okc_api.g_miss_char) THEN
         l_clev_rec.upg_orig_system_ref := NULL;
      END IF;
      IF (l_clev_rec.upg_orig_system_ref_id = okc_api.g_miss_num) THEN
         l_clev_rec.upg_orig_system_ref_id := NULL;
      END IF;
      IF (l_clev_rec.orig_system_source_code = okc_api.g_miss_char) THEN
         l_clev_rec.orig_system_source_code := NULL;
      END IF;
      IF (l_clev_rec.orig_system_id1 = okc_api.g_miss_num) THEN
         l_clev_rec.orig_system_id1 := NULL;
      END IF;
      IF (l_clev_rec.orig_system_reference1 = okc_api.g_miss_char) THEN
         l_clev_rec.orig_system_reference1 := NULL;
      END IF;
   
      IF (l_clev_rec.program_application_id = okc_api.g_miss_num) THEN
         l_clev_rec.program_application_id := NULL;
      END IF;
      IF (l_clev_rec.program_id = okc_api.g_miss_num) THEN
         l_clev_rec.program_id := NULL;
      END IF;
      IF (l_clev_rec.program_update_date = okc_api.g_miss_date) THEN
         l_clev_rec.program_update_date := NULL;
      END IF;
      IF (l_clev_rec.request_id = okc_api.g_miss_num) THEN
         l_clev_rec.request_id := NULL;
      END IF;
      IF (l_clev_rec.price_list_id = okc_api.g_miss_num) THEN
         l_clev_rec.price_list_id := NULL;
      END IF;
      IF (l_clev_rec.pricing_date = okc_api.g_miss_date) THEN
         l_clev_rec.pricing_date := NULL;
      END IF;
      IF (l_clev_rec.price_list_line_id = okc_api.g_miss_num) THEN
         l_clev_rec.price_list_line_id := NULL;
      END IF;
      IF (l_clev_rec.line_list_price = okc_api.g_miss_num) THEN
         l_clev_rec.line_list_price := NULL;
      END IF;
      IF (l_clev_rec.item_to_price_yn = okc_api.g_miss_char) THEN
         l_clev_rec.item_to_price_yn := NULL;
      END IF;
      IF (l_clev_rec.price_basis_yn = okc_api.g_miss_char) THEN
         l_clev_rec.price_basis_yn := NULL;
      END IF;
      IF (l_clev_rec.config_header_id = okc_api.g_miss_num) THEN
         l_clev_rec.config_header_id := NULL;
      END IF;
      IF (l_clev_rec.config_revision_number = okc_api.g_miss_num) THEN
         l_clev_rec.config_revision_number := NULL;
      END IF;
      IF (l_clev_rec.config_complete_yn = okc_api.g_miss_char) THEN
         l_clev_rec.config_complete_yn := NULL;
      END IF;
      IF (l_clev_rec.config_valid_yn = okc_api.g_miss_char) THEN
         l_clev_rec.config_valid_yn := NULL;
      END IF;
      IF (l_clev_rec.config_top_model_line_id = okc_api.g_miss_num) THEN
         l_clev_rec.config_top_model_line_id := NULL;
      END IF;
      IF (l_clev_rec.config_item_type = okc_api.g_miss_char) THEN
         l_clev_rec.config_item_type := NULL;
      END IF;
      --Bug.No-1942374--
      IF (l_clev_rec.config_item_id = okc_api.g_miss_num) THEN
         l_clev_rec.config_item_id := NULL;
      END IF;
      --bug.No-1942374--
      IF (l_clev_rec.attribute_category = okc_api.g_miss_char) THEN
         l_clev_rec.attribute_category := NULL;
      END IF;
      IF (l_clev_rec.attribute1 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute1 := NULL;
      END IF;
      IF (l_clev_rec.attribute2 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute2 := NULL;
      END IF;
      IF (l_clev_rec.attribute3 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute3 := NULL;
      END IF;
      IF (l_clev_rec.attribute4 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute4 := NULL;
      END IF;
      IF (l_clev_rec.attribute5 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute5 := NULL;
      END IF;
      IF (l_clev_rec.attribute6 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute6 := NULL;
      END IF;
      IF (l_clev_rec.attribute7 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute7 := NULL;
      END IF;
      IF (l_clev_rec.attribute8 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute8 := NULL;
      END IF;
      IF (l_clev_rec.attribute9 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute9 := NULL;
      END IF;
      IF (l_clev_rec.attribute10 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute10 := NULL;
      END IF;
      IF (l_clev_rec.attribute11 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute11 := NULL;
      END IF;
      IF (l_clev_rec.attribute12 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute12 := NULL;
      END IF;
      IF (l_clev_rec.attribute13 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute13 := NULL;
      END IF;
      IF (l_clev_rec.attribute14 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute14 := NULL;
      END IF;
      IF (l_clev_rec.attribute15 = okc_api.g_miss_char) THEN
         l_clev_rec.attribute15 := NULL;
      END IF;
      IF (l_clev_rec.created_by = okc_api.g_miss_num) THEN
         l_clev_rec.created_by := NULL;
      END IF;
      IF (l_clev_rec.creation_date = okc_api.g_miss_date) THEN
         l_clev_rec.creation_date := NULL;
      END IF;
      IF (l_clev_rec.last_updated_by = okc_api.g_miss_num) THEN
         l_clev_rec.last_updated_by := NULL;
      END IF;
      IF (l_clev_rec.last_update_date = okc_api.g_miss_date) THEN
         l_clev_rec.last_update_date := NULL;
      END IF;
      IF (l_clev_rec.price_type = okc_api.g_miss_char) THEN
         l_clev_rec.price_type := NULL;
      END IF;
      IF (l_clev_rec.currency_code = okc_api.g_miss_char) THEN
         l_clev_rec.currency_code := NULL;
      END IF;
      IF (l_clev_rec.currency_code_renewed = okc_api.g_miss_char) THEN
         l_clev_rec.currency_code_renewed := NULL;
      END IF;
      IF (l_clev_rec.last_update_login = okc_api.g_miss_num) THEN
         l_clev_rec.last_update_login := NULL;
      END IF;
      IF (l_clev_rec.service_item_yn = okc_api.g_miss_char) THEN
         l_clev_rec.service_item_yn := NULL;
      END IF;
      --new columns for price hold
      IF (l_clev_rec.ph_pricing_type = okc_api.g_miss_char) THEN
         l_clev_rec.ph_pricing_type := NULL;
      END IF;
      IF (l_clev_rec.ph_price_break_basis = okc_api.g_miss_char) THEN
         l_clev_rec.ph_price_break_basis := NULL;
      END IF;
      IF (l_clev_rec.ph_min_qty = okc_api.g_miss_num) THEN
         l_clev_rec.ph_min_qty := NULL;
      END IF;
      IF (l_clev_rec.ph_min_amt = okc_api.g_miss_num) THEN
         l_clev_rec.ph_min_amt := NULL;
      END IF;
      IF (l_clev_rec.ph_qp_reference_id = okc_api.g_miss_num) THEN
         l_clev_rec.ph_qp_reference_id := NULL;
      END IF;
      IF (l_clev_rec.ph_value = okc_api.g_miss_num) THEN
         l_clev_rec.ph_value := NULL;
      END IF;
      IF (l_clev_rec.ph_enforce_price_list_yn = okc_api.g_miss_char) THEN
         l_clev_rec.ph_enforce_price_list_yn := NULL;
      END IF;
      IF (l_clev_rec.ph_adjustment = okc_api.g_miss_num) THEN
         l_clev_rec.ph_adjustment := NULL;
      END IF;
      IF (l_clev_rec.ph_integrated_with_qp = okc_api.g_miss_char) THEN
         l_clev_rec.ph_integrated_with_qp := NULL;
      END IF;
      -- new  columns to replace rules
      IF (l_clev_rec.cust_acct_id = okc_api.g_miss_num) THEN
         l_clev_rec.cust_acct_id := NULL;
      END IF;
      IF (l_clev_rec.bill_to_site_use_id = okc_api.g_miss_num) THEN
         l_clev_rec.bill_to_site_use_id := NULL;
      END IF;
      IF (l_clev_rec.inv_rule_id = okc_api.g_miss_num) THEN
         l_clev_rec.inv_rule_id := NULL;
      END IF;
      IF (l_clev_rec.line_renewal_type_code = okc_api.g_miss_char) THEN
         l_clev_rec.line_renewal_type_code := NULL;
      END IF;
      IF (l_clev_rec.ship_to_site_use_id = okc_api.g_miss_num) THEN
         l_clev_rec.ship_to_site_use_id := NULL;
      END IF;
      IF (l_clev_rec.payment_term_id = okc_api.g_miss_num) THEN
         l_clev_rec.payment_term_id := NULL;
      END IF;
      -- Line level cancellation --
      IF (l_clev_rec.date_cancelled = okc_api.g_miss_date) THEN
         l_clev_rec.date_cancelled := NULL;
      END IF;
      /*IF (l_clev_rec.canc_reason_code = OKC_API.G_MISS_CHAR) THEN
        l_clev_rec.canc_reason_code := NULL;
      END IF;*/
      IF (l_clev_rec.term_cancel_source = okc_api.g_miss_char) THEN
         l_clev_rec.term_cancel_source := NULL;
      END IF;
      IF (l_clev_rec.cancelled_amount = okc_api.g_miss_num) THEN
         l_clev_rec.cancelled_amount := NULL;
      END IF;
      --added by mchoudha 22-JUL
      IF (l_clev_rec.payment_instruction_type = okc_api.g_miss_char) THEN
         l_clev_rec.payment_instruction_type := NULL;
      END IF;
      IF (l_clev_rec.annualized_factor = okc_api.g_miss_num) THEN
         l_clev_rec.annualized_factor := NULL;
      END IF;
   
      --
      IF (l_debug = 'Y') THEN
         okc_debug.log('11450: Leaving  Fn  null_out_defaults ', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN(l_clev_rec);
   
   END null_out_defaults;
   ---------------------------------------------------------------------------
   -- PROCEDURE Validate_Attributes
   ---------------------------------------------------------------------------
   -------------------------------------------
   -- Validate_Attributes for:OKC_K_LINES_V --
   -------------------------------------------
   FUNCTION validate_attributes(p_clev_rec IN clev_rec_type) RETURN VARCHAR2 IS
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      x_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      /* Bug 3652127 */
      l_application_id NUMBER;
      CURSOR l_application_csr IS
      --npalepu 08-11-2005 modified for bug # 4691662.
      --Replaced table okc_k_headers_b with headers_All_b table
      /* Select application_id from okc_k_headers_b */
         SELECT application_id
           FROM okc_k_headers_all_b
         --end npalepu
          WHERE id = p_clev_rec.dnz_chr_id;
   
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('11500: Entered Validate_Attributes', 2);
      END IF;
   
      /************************ HAND-CODED *********************************/
      validate_line_number(x_return_status => l_return_status,
                           p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_chr_id(x_return_status => l_return_status,
                      p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_cle_id(x_return_status => l_return_status,
                      p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_lse_id(x_return_status => l_return_status,
                      p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_display_sequence(x_return_status => l_return_status,
                                p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_dnz_chr_id(x_return_status => l_return_status,
                          p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_exception_yn(x_return_status => l_return_status,
                            p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_hidden_ind(x_return_status => l_return_status,
                          p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_price_level_ind(x_return_status => l_return_status,
                               p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_inv_line_level_ind(x_return_status => l_return_status,
                                  p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_price_type(x_return_status => l_return_status,
                          p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_sts_code(x_return_status => l_return_status,
                        p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_currency_code(x_return_status => l_return_status,
                             p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_start_date(x_return_status => l_return_status,
                          p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_end_date(x_return_status => l_return_status,
                        p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_curr_code_rnwd(x_return_status => l_return_status,
                              p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
   
      validate_orig_sys_code(x_return_status => l_return_status,
                             p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      ---------------------------
      validate_config_complete_yn(x_return_status => l_return_status,
                                  p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      -------------------------
      validate_config_valid_yn(x_return_status => l_return_status,
                               p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_item_to_price_yn(x_return_status => l_return_status,
                                p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_price_basis_yn(x_return_status => l_return_status,
                              p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_config_item_type(x_return_status => l_return_status,
                                p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      /* Bug 3652127 - price list  check not done for application id 515(OKS) */
   
      OPEN l_application_csr;
      FETCH l_application_csr
         INTO l_application_id;
      CLOSE l_application_csr;
   
      IF l_application_id <> 515 THEN
         validate_price_list_id(x_return_status => l_return_status,
                                p_clev_rec      => p_clev_rec);
      
         -- store the highest degree of error
         IF l_return_status <> okc_api.g_ret_sts_success THEN
            IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
               x_return_status := l_return_status;
            END IF;
         END IF;
      END IF;
      -----------------------------
      validate_price_list_line_id(x_return_status => l_return_status,
                                  p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_ph_pricing_type(x_return_status => l_return_status,
                               p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_ph_price_break_basis(x_return_status => l_return_status,
                                    p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_ph_qp_reference_id(x_return_status => l_return_status,
                                  p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_ph_enforce_price_list(x_return_status => l_return_status,
                                     p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_ph_integrated_with_qp(x_return_status => l_return_status,
                                     p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      --------------------------
      validate_line_renewal_type(x_return_status => l_return_status,
                                 p_clev_rec      => p_clev_rec);
   
      -- store the highest degree of error
      IF l_return_status <> okc_api.g_ret_sts_success THEN
         IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
            x_return_status := l_return_status;
         END IF;
      END IF;
      ----------------------------
      -- return status to caller
      RETURN(x_return_status);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('11600: Exiting Validate_Attributes', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('11700: Exiting Validate_Attributes:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         -- notify caller of an UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
         -- return status to caller
         RETURN(x_return_status);
         --------------------------------
         validate_conf_top_mod_ln_id(x_return_status => l_return_status,
                                     p_clev_rec      => p_clev_rec);
      
         -- store the highest degree of error
         IF l_return_status <> okc_api.g_ret_sts_success THEN
            IF x_return_status <> okc_api.g_ret_sts_unexp_error THEN
               x_return_status := l_return_status;
            END IF;
         END IF;
         /*********************** END HAND-CODED ********************************/
   
   END validate_attributes;

   ---------------------------------------------------------------------------
   -- PROCEDURE Validate_Record
   ---------------------------------------------------------------------------
   ---------------------------------------
   -- Validate_Record for:OKC_K_LINES_V --
   ---------------------------------------
   FUNCTION validate_record(p_clev_rec IN clev_rec_type) RETURN VARCHAR2 IS
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      -- Cursor to get header  end dates
      CURSOR l_chrv_csr IS
         SELECT end_date
         --npalepu 08-11-2005 modified for bug # 4691662.
         --Replaced table okc_k_headers_b with headers_All_b table
         /* FROM OKC_K_HEADERS_B */
           FROM okc_k_headers_all_b
         --end npalepu
          WHERE id = p_clev_rec.dnz_chr_id;
      l_end_date DATE;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('11800: Entered Validate_Record', 2);
      END IF;
   
      /************************ HAND-CODED ****************************/
      -- CHR_ID and CLE_ID are mutually exclusive
      IF (p_clev_rec.chr_id IS NULL AND p_clev_rec.cle_id IS NULL) OR
         (p_clev_rec.chr_id IS NOT NULL AND p_clev_rec.cle_id IS NOT NULL) THEN
         l_return_status := okc_api.g_ret_sts_error;
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_invalid_value,
                             p_token1       => g_col_name_token,
                             p_token1_value => 'chr_id',
                             p_token2       => g_col_name_token,
                             p_token2_value => 'cle_id');
      END IF;
      ---Pricing date cannot be greater than line/contract end date for advanced pricing
   
      IF ((l_return_status = okc_api.g_ret_sts_success) AND
         nvl(fnd_profile.VALUE('OKC_ADVANCED_PRICING'), 'N') = 'Y') THEN
         IF p_clev_rec.pricing_date IS NOT NULL THEN
         
            OPEN l_chrv_csr;
            FETCH l_chrv_csr
               INTO l_end_date;
            CLOSE l_chrv_csr;
         END IF;
      
         IF (p_clev_rec.end_date IS NOT NULL OR l_end_date IS NOT NULL) THEN
            IF (p_clev_rec.pricing_date >
               nvl(p_clev_rec.end_date, l_end_date)) THEN
               -- notify caller of an error as UNEXPETED error
               l_return_status := okc_api.g_ret_sts_error;
               okc_api.set_message(p_app_name => g_app_name,
                                   p_msg_name => 'OKC_INVALID_LINE_PRICING_DATE');
            END IF;
         END IF;
      END IF;
   
      /*********************** END HAND-CODED *************************/
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('11850: Exiting Validate_Record ', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN(l_return_status);
   
   END validate_record;

   ---------------------------------------------------------------------------
   -- PROCEDURE Migrate
   ---------------------------------------------------------------------------
   PROCEDURE migrate(p_from IN clev_rec_type,
                     p_to   IN OUT NOCOPY cle_rec_type) IS
   BEGIN
   
      p_to.id                       := p_from.id;
      p_to.line_number              := p_from.line_number;
      p_to.chr_id                   := p_from.chr_id;
      p_to.cle_id                   := p_from.cle_id;
      p_to.dnz_chr_id               := p_from.dnz_chr_id;
      p_to.display_sequence         := p_from.display_sequence;
      p_to.sts_code                 := p_from.sts_code;
      p_to.trn_code                 := p_from.trn_code;
      p_to.lse_id                   := p_from.lse_id;
      p_to.exception_yn             := p_from.exception_yn;
      p_to.object_version_number    := p_from.object_version_number;
      p_to.created_by               := p_from.created_by;
      p_to.creation_date            := p_from.creation_date;
      p_to.last_updated_by          := p_from.last_updated_by;
      p_to.last_update_date         := p_from.last_update_date;
      p_to.hidden_ind               := p_from.hidden_ind;
      p_to.price_unit               := p_from.price_unit;
      p_to.price_unit_percent       := p_from.price_unit_percent;
      p_to.price_negotiated         := p_from.price_negotiated;
      p_to.price_negotiated_renewed := p_from.price_negotiated_renewed;
      p_to.price_level_ind          := p_from.price_level_ind;
      p_to.invoice_line_level_ind   := p_from.invoice_line_level_ind;
      p_to.dpas_rating              := p_from.dpas_rating;
      p_to.template_used            := p_from.template_used;
      p_to.price_type               := p_from.price_type;
      p_to.currency_code            := p_from.currency_code;
      p_to.currency_code_renewed    := p_from.currency_code_renewed;
      p_to.last_update_login        := p_from.last_update_login;
      p_to.date_terminated          := p_from.date_terminated;
      p_to.start_date               := p_from.start_date;
      p_to.end_date                 := p_from.end_date;
      p_to.date_renewed             := p_from.date_renewed;
      p_to.upg_orig_system_ref      := p_from.upg_orig_system_ref;
      p_to.upg_orig_system_ref_id   := p_from.upg_orig_system_ref_id;
      p_to.orig_system_source_code  := p_from.orig_system_source_code;
      p_to.orig_system_id1          := p_from.orig_system_id1;
      p_to.orig_system_reference1   := p_from.orig_system_reference1;
      p_to.request_id               := p_from.request_id;
      p_to.program_application_id   := p_from.program_application_id;
      p_to.program_id               := p_from.program_id;
      p_to.program_update_date      := p_from.program_update_date;
      p_to.price_list_id            := p_from.price_list_id;
      p_to.pricing_date             := p_from.pricing_date;
      p_to.price_list_line_id       := p_from.price_list_line_id;
      p_to.line_list_price          := p_from.line_list_price;
      p_to.item_to_price_yn         := p_from.item_to_price_yn;
      p_to.price_basis_yn           := p_from.price_basis_yn;
      p_to.config_header_id         := p_from.config_header_id;
      p_to.config_revision_number   := p_from.config_revision_number;
      p_to.config_complete_yn       := p_from.config_complete_yn;
      p_to.config_valid_yn          := p_from.config_valid_yn;
      p_to.config_top_model_line_id := p_from.config_top_model_line_id;
      p_to.config_item_type         := p_from.config_item_type;
      ---Bug.No.-1942374
      p_to.config_item_id := p_from.config_item_id;
      ---Bug.No.-1942374
      p_to.attribute_category := p_from.attribute_category;
      p_to.attribute1         := p_from.attribute1;
      p_to.attribute2         := p_from.attribute2;
      p_to.attribute3         := p_from.attribute3;
      p_to.attribute4         := p_from.attribute4;
      p_to.attribute5         := p_from.attribute5;
      p_to.attribute6         := p_from.attribute6;
      p_to.attribute7         := p_from.attribute7;
      p_to.attribute8         := p_from.attribute8;
      p_to.attribute9         := p_from.attribute9;
      p_to.attribute10        := p_from.attribute10;
      p_to.attribute11        := p_from.attribute11;
      p_to.attribute12        := p_from.attribute12;
      p_to.attribute13        := p_from.attribute13;
      p_to.attribute14        := p_from.attribute14;
      p_to.attribute15        := p_from.attribute15;
      p_to.service_item_yn    := p_from.service_item_yn;
      --new columns for price hold
      p_to.ph_pricing_type          := p_from.ph_pricing_type;
      p_to.ph_price_break_basis     := p_from.ph_price_break_basis;
      p_to.ph_min_qty               := p_from.ph_min_qty;
      p_to.ph_min_amt               := p_from.ph_min_amt;
      p_to.ph_qp_reference_id       := p_from.ph_qp_reference_id;
      p_to.ph_value                 := p_from.ph_value;
      p_to.ph_enforce_price_list_yn := p_from.ph_enforce_price_list_yn;
      p_to.ph_adjustment            := p_from.ph_adjustment;
      p_to.ph_integrated_with_qp    := p_from.ph_integrated_with_qp;
   
      --new columns to replace rules
   
      p_to.cust_acct_id           := p_from.cust_acct_id;
      p_to.bill_to_site_use_id    := p_from.bill_to_site_use_id;
      p_to.inv_rule_id            := p_from.inv_rule_id;
      p_to.line_renewal_type_code := p_from.line_renewal_type_code;
      p_to.ship_to_site_use_id    := p_from.ship_to_site_use_id;
      p_to.payment_term_id        := p_from.payment_term_id;
   
      ---Line Level Cancellation ---
      p_to.date_cancelled := p_from.date_cancelled;
      --p_to.canc_reason_code := p_from.canc_reason_code;
      p_to.term_cancel_source := p_from.term_cancel_source;
      p_to.cancelled_amount   := p_from.cancelled_amount;
      --added by mchoudha 22-JUL
      p_to.annualized_factor        := p_from.annualized_factor;
      p_to.payment_instruction_type := p_from.payment_instruction_type;
   
   END migrate;

   PROCEDURE migrate(p_from IN cle_rec_type,
                     p_to   IN OUT NOCOPY clev_rec_type) IS
   BEGIN
   
      p_to.id                       := p_from.id;
      p_to.line_number              := p_from.line_number;
      p_to.chr_id                   := p_from.chr_id;
      p_to.cle_id                   := p_from.cle_id;
      p_to.dnz_chr_id               := p_from.dnz_chr_id;
      p_to.display_sequence         := p_from.display_sequence;
      p_to.sts_code                 := p_from.sts_code;
      p_to.trn_code                 := p_from.trn_code;
      p_to.lse_id                   := p_from.lse_id;
      p_to.exception_yn             := p_from.exception_yn;
      p_to.object_version_number    := p_from.object_version_number;
      p_to.created_by               := p_from.created_by;
      p_to.creation_date            := p_from.creation_date;
      p_to.last_updated_by          := p_from.last_updated_by;
      p_to.last_update_date         := p_from.last_update_date;
      p_to.hidden_ind               := p_from.hidden_ind;
      p_to.price_unit               := p_from.price_unit;
      p_to.price_unit_percent       := p_from.price_unit_percent;
      p_to.price_negotiated         := p_from.price_negotiated;
      p_to.price_negotiated_renewed := p_from.price_negotiated_renewed;
      p_to.price_level_ind          := p_from.price_level_ind;
      p_to.invoice_line_level_ind   := p_from.invoice_line_level_ind;
      p_to.dpas_rating              := p_from.dpas_rating;
      p_to.template_used            := p_from.template_used;
      p_to.price_type               := p_from.price_type;
      p_to.currency_code            := p_from.currency_code;
      p_to.currency_code_renewed    := p_from.currency_code_renewed;
      p_to.last_update_login        := p_from.last_update_login;
      p_to.date_terminated          := p_from.date_terminated;
      p_to.start_date               := p_from.start_date;
      p_to.end_date                 := p_from.end_date;
      p_to.date_renewed             := p_from.date_renewed;
      p_to.upg_orig_system_ref      := p_from.upg_orig_system_ref;
      p_to.upg_orig_system_ref_id   := p_from.upg_orig_system_ref_id;
      p_to.orig_system_source_code  := p_from.orig_system_source_code;
      p_to.orig_system_id1          := p_from.orig_system_id1;
      p_to.orig_system_reference1   := p_from.orig_system_reference1;
      p_to.request_id               := p_from.request_id;
      p_to.program_application_id   := p_from.program_application_id;
      p_to.program_id               := p_from.program_id;
      p_to.program_update_date      := p_from.program_update_date;
      p_to.price_list_id            := p_from.price_list_id;
      p_to.pricing_date             := p_from.pricing_date;
      p_to.price_list_line_id       := p_from.price_list_line_id;
      p_to.line_list_price          := p_from.line_list_price;
      p_to.item_to_price_yn         := p_from.item_to_price_yn;
      p_to.price_basis_yn           := p_from.price_basis_yn;
      p_to.config_header_id         := p_from.config_header_id;
      p_to.config_revision_number   := p_from.config_revision_number;
      p_to.config_complete_yn       := p_from.config_complete_yn;
      p_to.config_valid_yn          := p_from.config_valid_yn;
      p_to.config_top_model_line_id := p_from.config_top_model_line_id;
      p_to.config_item_type         := p_from.config_item_type;
      ---Bug.No.1942374-
      p_to.config_item_id := p_from.config_item_id;
      ---Bug.No.1942374-
      p_to.attribute_category := p_from.attribute_category;
      p_to.attribute1         := p_from.attribute1;
      p_to.attribute2         := p_from.attribute2;
      p_to.attribute3         := p_from.attribute3;
      p_to.attribute4         := p_from.attribute4;
      p_to.attribute5         := p_from.attribute5;
      p_to.attribute6         := p_from.attribute6;
      p_to.attribute7         := p_from.attribute7;
      p_to.attribute8         := p_from.attribute8;
      p_to.attribute9         := p_from.attribute9;
      p_to.attribute10        := p_from.attribute10;
      p_to.attribute11        := p_from.attribute11;
      p_to.attribute12        := p_from.attribute12;
      p_to.attribute13        := p_from.attribute13;
      p_to.attribute14        := p_from.attribute14;
      p_to.attribute15        := p_from.attribute15;
      p_to.service_item_yn    := p_from.service_item_yn;
      --new columns for price hold
      p_to.ph_pricing_type          := p_from.ph_pricing_type;
      p_to.ph_price_break_basis     := p_from.ph_price_break_basis;
      p_to.ph_min_qty               := p_from.ph_min_qty;
      p_to.ph_min_amt               := p_from.ph_min_amt;
      p_to.ph_qp_reference_id       := p_from.ph_qp_reference_id;
      p_to.ph_value                 := p_from.ph_value;
      p_to.ph_enforce_price_list_yn := p_from.ph_enforce_price_list_yn;
      p_to.ph_adjustment            := p_from.ph_adjustment;
      p_to.ph_integrated_with_qp    := p_from.ph_integrated_with_qp;
      --new columns to replace rules
   
      p_to.cust_acct_id           := p_from.cust_acct_id;
      p_to.bill_to_site_use_id    := p_from.bill_to_site_use_id;
      p_to.inv_rule_id            := p_from.inv_rule_id;
      p_to.line_renewal_type_code := p_from.line_renewal_type_code;
      p_to.ship_to_site_use_id    := p_from.ship_to_site_use_id;
      p_to.payment_term_id        := p_from.payment_term_id;
   
      -- Line level cancellation --
      p_to.date_cancelled := p_from.date_cancelled;
      --p_to.canc_reason_code  := p_from.canc_reason_code;
      p_to.term_cancel_source := p_from.term_cancel_source;
      p_to.cancelled_amount   := p_from.cancelled_amount;
      --added by mchoudha 22-JUL
      p_to.annualized_factor        := p_from.annualized_factor;
      p_to.payment_instruction_type := p_from.payment_instruction_type;
   
   END migrate;

   PROCEDURE migrate(p_from IN clev_rec_type,
                     p_to   IN OUT NOCOPY okc_k_lines_tl_rec_type) IS
   BEGIN
   
      p_to.id                  := p_from.id;
      p_to.sfwt_flag           := p_from.sfwt_flag;
      p_to.NAME                := p_from.NAME;
      p_to.comments            := p_from.comments;
      p_to.item_description    := p_from.item_description;
      p_to.oke_boe_description := p_from.oke_boe_description;
      p_to.cognomen            := p_from.cognomen;
      p_to.block23text         := p_from.block23text;
      p_to.created_by          := p_from.created_by;
      p_to.creation_date       := p_from.creation_date;
      p_to.last_updated_by     := p_from.last_updated_by;
      p_to.last_update_date    := p_from.last_update_date;
      p_to.last_update_login   := p_from.last_update_login;
   
   END migrate;

   PROCEDURE migrate(p_from IN okc_k_lines_tl_rec_type,
                     p_to   IN OUT NOCOPY clev_rec_type) IS
   BEGIN
   
      p_to.id                  := p_from.id;
      p_to.sfwt_flag           := p_from.sfwt_flag;
      p_to.NAME                := p_from.NAME;
      p_to.comments            := p_from.comments;
      p_to.item_description    := p_from.item_description;
      p_to.oke_boe_description := p_from.oke_boe_description;
      p_to.cognomen            := p_from.cognomen;
      p_to.block23text         := p_from.block23text;
      p_to.created_by          := p_from.created_by;
      p_to.creation_date       := p_from.creation_date;
      p_to.last_updated_by     := p_from.last_updated_by;
      p_to.last_update_date    := p_from.last_update_date;
      p_to.last_update_login   := p_from.last_update_login;
   
   END migrate;

   ---------------------------------------------------------------------------
   -- PROCEDURE validate_row
   ---------------------------------------------------------------------------
   ------------------------------------
   -- validate_row for:OKC_K_LINES_V --
   ------------------------------------
   PROCEDURE validate_row(p_api_version   IN NUMBER,
                          p_init_msg_list IN VARCHAR2,
                          x_return_status OUT NOCOPY VARCHAR2,
                          x_msg_count     OUT NOCOPY NUMBER,
                          x_msg_data      OUT NOCOPY VARCHAR2,
                          p_clev_rec      IN clev_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_validate_row';
      l_return_status      VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_clev_rec           clev_rec_type := p_clev_rec;
      l_cle_rec            cle_rec_type;
      l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('12300: Entered validate_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                g_pkg_name,
                                                p_init_msg_list,
                                                l_api_version,
                                                p_api_version,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
   
      IF p_clev_rec.validate_yn = 'Y' THEN
         ---Bug#3150149
         --- Validate all non-missing attributes (Item Level Validation)
         l_return_status := validate_attributes(l_clev_rec);
      END IF; ---Bug#3150149
   
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_return_status := validate_record(l_clev_rec);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('12400: Exiting validate_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('12500: Exiting validate_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('12600: Exiting validate_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('12700: Exiting validate_row:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END validate_row;
   ------------------------------------------
   -- PL/SQL TBL validate_row for:CLEV_TBL --
   ------------------------------------------
   PROCEDURE validate_row(p_api_version   IN NUMBER,
                          p_init_msg_list IN VARCHAR2,
                          x_return_status OUT NOCOPY VARCHAR2,
                          x_msg_count     OUT NOCOPY NUMBER,
                          x_msg_data      OUT NOCOPY VARCHAR2,
                          p_clev_tbl      IN clev_tbl_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_tbl_validate_row';
      l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      i                NUMBER := 0;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('12800: Entered validate_row', 2);
      END IF;
   
      okc_api.init_msg_list(p_init_msg_list);
      -- Make sure PL/SQL table has records in it before passing
      IF (p_clev_tbl.COUNT > 0) THEN
         i := p_clev_tbl.FIRST;
         LOOP
            validate_row(p_api_version   => p_api_version,
                         p_init_msg_list => okc_api.g_false,
                         x_return_status => x_return_status,
                         x_msg_count     => x_msg_count,
                         x_msg_data      => x_msg_data,
                         p_clev_rec      => p_clev_tbl(i));
         
            -- store the highest degree of error
            IF x_return_status <> okc_api.g_ret_sts_success THEN
               IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                  l_overall_status := x_return_status;
               END IF;
            END IF;
         
            EXIT WHEN(i = p_clev_tbl.LAST);
            i := p_clev_tbl.NEXT(i);
         END LOOP;
         -- return overall status
         x_return_status := l_overall_status;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('12900: Exiting validate_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('13000: Exiting validate_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('13100: Exiting validate_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('13200: Exiting validate_row:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END validate_row;

   ---------------------------------------------------------------------------
   -- PROCEDURE insert_row
   ---------------------------------------------------------------------------
   ----------------------------------
   -- insert_row for:OKC_K_LINES_B --
   ----------------------------------
   PROCEDURE insert_row(p_init_msg_list IN VARCHAR2,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_cle_rec       IN cle_rec_type,
                        x_cle_rec       OUT NOCOPY cle_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'B_insert_row';
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_cle_rec       cle_rec_type := p_cle_rec;
      l_def_cle_rec   cle_rec_type;
      --------------------------------------
      -- Set_Attributes for:OKC_K_LINES_B --
      --------------------------------------
      FUNCTION set_attributes(p_cle_rec IN cle_rec_type,
                              x_cle_rec OUT NOCOPY cle_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_cle_rec := p_cle_rec;
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('13400: Entered insert_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --- Setting item attributes
      l_return_status := set_attributes(p_cle_rec, -- IN
                                        l_cle_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      INSERT INTO okc_k_lines_b
         (id,
          line_number,
          chr_id,
          cle_id,
          dnz_chr_id,
          display_sequence,
          sts_code,
          trn_code,
          lse_id,
          exception_yn,
          object_version_number,
          created_by,
          creation_date,
          last_updated_by,
          last_update_date,
          hidden_ind,
          price_unit,
          price_unit_percent,
          price_negotiated,
          price_negotiated_renewed,
          price_level_ind,
          invoice_line_level_ind,
          dpas_rating,
          template_used,
          price_type,
          currency_code,
          currency_code_renewed,
          last_update_login,
          date_terminated,
          start_date,
          end_date,
          date_renewed,
          upg_orig_system_ref,
          upg_orig_system_ref_id,
          orig_system_source_code,
          orig_system_id1,
          orig_system_reference1,
          program_id,
          request_id,
          program_update_date,
          program_application_id,
          price_list_id,
          pricing_date,
          price_list_line_id,
          line_list_price,
          item_to_price_yn,
          price_basis_yn,
          config_header_id,
          config_revision_number,
          config_complete_yn,
          config_valid_yn,
          config_top_model_line_id,
          config_item_type,
          ---Bug.No.-1942374
          config_item_id,
          ---Bug.No.-1942374
          attribute_category,
          attribute1,
          attribute2,
          attribute3,
          attribute4,
          attribute5,
          attribute6,
          attribute7,
          attribute8,
          attribute9,
          attribute10,
          attribute11,
          attribute12,
          attribute13,
          attribute14,
          attribute15,
          service_item_yn,
          --new columns for price hold
          ph_pricing_type,
          ph_price_break_basis,
          ph_min_qty,
          ph_min_amt,
          ph_qp_reference_id,
          ph_value,
          ph_enforce_price_list_yn,
          ph_adjustment,
          ph_integrated_with_qp,
          --new columns to replace rules
          cust_acct_id,
          bill_to_site_use_id,
          inv_rule_id,
          line_renewal_type_code,
          ship_to_site_use_id,
          payment_term_id,
          payment_instruction_type, --added by mchoudha 22-JUL
          ---NPALEPU on 03-JUN-2005 Added new column for Annualized Amount
          annualized_factor,
          /*** R12 Data Model Changes Start  **/
          date_cancelled,
          -- canc_reason_code     ,
          term_cancel_source,
          cancelled_amount
          /**  R12 Data Model Changes End ***/)
      VALUES
         (l_cle_rec.id,
          l_cle_rec.line_number,
          l_cle_rec.chr_id,
          l_cle_rec.cle_id,
          l_cle_rec.dnz_chr_id,
          l_cle_rec.display_sequence,
          l_cle_rec.sts_code,
          l_cle_rec.trn_code,
          l_cle_rec.lse_id,
          l_cle_rec.exception_yn,
          l_cle_rec.object_version_number,
          l_cle_rec.created_by,
          l_cle_rec.creation_date,
          l_cle_rec.last_updated_by,
          l_cle_rec.last_update_date,
          l_cle_rec.hidden_ind,
          l_cle_rec.price_unit,
          l_cle_rec.price_unit_percent,
          l_cle_rec.price_negotiated,
          l_cle_rec.price_negotiated_renewed,
          l_cle_rec.price_level_ind,
          l_cle_rec.invoice_line_level_ind,
          l_cle_rec.dpas_rating,
          l_cle_rec.template_used,
          l_cle_rec.price_type,
          l_cle_rec.currency_code,
          l_cle_rec.currency_code_renewed,
          l_cle_rec.last_update_login,
          l_cle_rec.date_terminated,
          l_cle_rec.start_date,
          l_cle_rec.end_date,
          l_cle_rec.date_renewed,
          l_cle_rec.upg_orig_system_ref,
          l_cle_rec.upg_orig_system_ref_id,
          l_cle_rec.orig_system_source_code,
          l_cle_rec.orig_system_id1,
          l_cle_rec.orig_system_reference1,
          decode(fnd_global.conc_program_id,
                 -1,
                 NULL,
                 fnd_global.conc_program_id),
          decode(fnd_global.conc_request_id,
                 -1,
                 NULL,
                 fnd_global.conc_request_id),
          decode(fnd_global.conc_request_id, -1, NULL, SYSDATE),
          decode(fnd_global.prog_appl_id, -1, NULL, fnd_global.prog_appl_id),
          l_cle_rec.price_list_id,
          l_cle_rec.pricing_date,
          l_cle_rec.price_list_line_id,
          l_cle_rec.line_list_price,
          l_cle_rec.item_to_price_yn,
          l_cle_rec.price_basis_yn,
          l_cle_rec.config_header_id,
          l_cle_rec.config_revision_number,
          l_cle_rec.config_complete_yn,
          l_cle_rec.config_valid_yn,
          l_cle_rec.config_top_model_line_id,
          l_cle_rec.config_item_type,
          ---Bug.No.-1942374
          l_cle_rec.config_item_id,
          ---Bug.No.-1942374
          l_cle_rec.attribute_category,
          l_cle_rec.attribute1,
          l_cle_rec.attribute2,
          l_cle_rec.attribute3,
          l_cle_rec.attribute4,
          l_cle_rec.attribute5,
          l_cle_rec.attribute6,
          l_cle_rec.attribute7,
          l_cle_rec.attribute8,
          l_cle_rec.attribute9,
          l_cle_rec.attribute10,
          l_cle_rec.attribute11,
          l_cle_rec.attribute12,
          l_cle_rec.attribute13,
          l_cle_rec.attribute14,
          l_cle_rec.attribute15,
          l_cle_rec.service_item_yn,
          -- new columns for price hold
          l_cle_rec.ph_pricing_type,
          l_cle_rec.ph_price_break_basis,
          l_cle_rec.ph_min_qty,
          l_cle_rec.ph_min_amt,
          l_cle_rec.ph_qp_reference_id,
          l_cle_rec.ph_value,
          l_cle_rec.ph_enforce_price_list_yn,
          l_cle_rec.ph_adjustment,
          l_cle_rec.ph_integrated_with_qp,
          --new columns to replace rules
          l_cle_rec.cust_acct_id,
          l_cle_rec.bill_to_site_use_id,
          l_cle_rec.inv_rule_id,
          l_cle_rec.line_renewal_type_code,
          l_cle_rec.ship_to_site_use_id,
          l_cle_rec.payment_term_id,
          l_cle_rec.payment_instruction_type, --added by mchoudha 22-JUL
          --NPALEPU on 03-JUN-2005 Added new column for Annualized Amounts
          nvl((SELECT (add_months(l_cle_rec.start_date, (nyears + 1) * 12) -
                     l_cle_rec.start_date -
                     decode(add_months(l_cle_rec.end_date, -12),
                             (l_cle_rec.end_date - 366),
                             0,
                             decode(add_months(l_cle_rec.start_date,
                                               (nyears + 1) * 12) -
                                    add_months(l_cle_rec.start_date,
                                               nyears * 12),
                                    366,
                                    1,
                                    0))) / (nyears + 1) /
                     (l_cle_rec.end_date - l_cle_rec.start_date + 1)
                FROM (SELECT trunc(months_between(l_cle_rec.end_date,
                                                  l_cle_rec.start_date) / 12) nyears
                        FROM dual) dual
               WHERE l_cle_rec.lse_id IN
                     (1, 12, 14, 19, 46, 7, 8, 9, 10, 11, 13, 18, 25, 35)),
              0),
          /*** R12 Data Model Changes Start  **/
          l_cle_rec.date_cancelled,
          --l_cle_rec.canc_reason_code        ,
          l_cle_rec.term_cancel_source,
          l_cle_rec.cancelled_amount
          /**  R12 Data Model Changes End ***/);
      --END NPALEPU
      -- Set OUT values
      x_cle_rec := l_cle_rec;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('13500: Exiting insert_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('13600: Exiting insert_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('13700: Exiting insert_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('13800: Exiting insert_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END insert_row;
   -----------------------------------
   -- insert_row for:OKC_K_LINES_TL --
   -----------------------------------
   PROCEDURE insert_row(p_init_msg_list      IN VARCHAR2,
                        x_return_status      OUT NOCOPY VARCHAR2,
                        x_msg_count          OUT NOCOPY NUMBER,
                        x_msg_data           OUT NOCOPY VARCHAR2,
                        p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                        x_okc_k_lines_tl_rec OUT NOCOPY okc_k_lines_tl_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'TL_insert_row';
      l_return_status          VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_okc_k_lines_tl_rec     okc_k_lines_tl_rec_type := p_okc_k_lines_tl_rec;
      l_def_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
      CURSOR get_languages IS
         SELECT * FROM fnd_languages WHERE installed_flag IN ('I', 'B');
      ---------------------------------------
      -- Set_Attributes for:OKC_K_LINES_TL --
      ---------------------------------------
      FUNCTION set_attributes(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                              x_okc_k_lines_tl_rec OUT NOCOPY okc_k_lines_tl_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_okc_k_lines_tl_rec             := p_okc_k_lines_tl_rec;
         x_okc_k_lines_tl_rec.LANGUAGE    := okc_util.get_userenv_lang;
         x_okc_k_lines_tl_rec.source_lang := okc_util.get_userenv_lang;
      
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('14000: Entered insert_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --- Setting item attributes
      l_return_status := set_attributes(p_okc_k_lines_tl_rec, -- IN
                                        l_okc_k_lines_tl_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      FOR l_lang_rec IN get_languages LOOP
         l_okc_k_lines_tl_rec.LANGUAGE := l_lang_rec.language_code;
         INSERT INTO okc_k_lines_tl
            (id,
             LANGUAGE,
             source_lang,
             sfwt_flag,
             NAME,
             comments,
             item_description,
             oke_boe_description,
             cognomen,
             block23text,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             last_update_login)
         VALUES
            (l_okc_k_lines_tl_rec.id,
             l_okc_k_lines_tl_rec.LANGUAGE,
             l_okc_k_lines_tl_rec.source_lang,
             l_okc_k_lines_tl_rec.sfwt_flag,
             l_okc_k_lines_tl_rec.NAME,
             l_okc_k_lines_tl_rec.comments,
             l_okc_k_lines_tl_rec.item_description,
             l_okc_k_lines_tl_rec.oke_boe_description,
             l_okc_k_lines_tl_rec.cognomen,
             l_okc_k_lines_tl_rec.block23text,
             l_okc_k_lines_tl_rec.created_by,
             l_okc_k_lines_tl_rec.creation_date,
             l_okc_k_lines_tl_rec.last_updated_by,
             l_okc_k_lines_tl_rec.last_update_date,
             l_okc_k_lines_tl_rec.last_update_login);
      END LOOP;
      -- Set OUT values
      x_okc_k_lines_tl_rec := l_okc_k_lines_tl_rec;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('14100: Exiting insert_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('14200: Exiting insert_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('14300: Exiting insert_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('14400: Exiting insert_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END insert_row;
   ----------------------------------
   -- insert_row for:OKC_K_LINES_V --
   ----------------------------------
   PROCEDURE insert_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_rec      IN clev_rec_type,
                        x_clev_rec      OUT NOCOPY clev_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_insert_row';
      l_return_status       VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_clev_rec            clev_rec_type;
      l_def_clev_rec        clev_rec_type;
      l_cle_rec             cle_rec_type;
      lx_cle_rec            cle_rec_type;
      l_okc_k_lines_tl_rec  okc_k_lines_tl_rec_type;
      lx_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
      -------------------------------
      -- FUNCTION fill_who_columns --
      -------------------------------
      FUNCTION fill_who_columns(p_clev_rec IN clev_rec_type)
         RETURN clev_rec_type IS
         l_clev_rec clev_rec_type := p_clev_rec;
      BEGIN
      
         l_clev_rec.creation_date     := SYSDATE;
         l_clev_rec.created_by        := fnd_global.user_id;
         l_clev_rec.last_update_date  := l_clev_rec.creation_date;
         l_clev_rec.last_updated_by   := fnd_global.user_id;
         l_clev_rec.last_update_login := fnd_global.login_id;
      
         RETURN(l_clev_rec);
      
      END fill_who_columns;
      --------------------------------------
      -- Set_Attributes for:OKC_K_LINES_V --
      --------------------------------------
      FUNCTION set_attributes(p_clev_rec IN clev_rec_type,
                              x_clev_rec OUT NOCOPY clev_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_clev_rec                       := p_clev_rec;
         x_clev_rec.object_version_number := 1;
         x_clev_rec.sfwt_flag             := 'N';
         /************************ HAND-CODED *********************************/
         x_clev_rec.hidden_ind      := upper(x_clev_rec.hidden_ind);
         x_clev_rec.price_level_ind := upper(x_clev_rec.price_level_ind);
         IF (x_clev_rec.price_level_ind IS NULL OR
            x_clev_rec.price_level_ind = okc_api.g_miss_char) THEN
            x_clev_rec.price_level_ind := 'N';
         END IF;
         x_clev_rec.invoice_line_level_ind := upper(x_clev_rec.invoice_line_level_ind);
         x_clev_rec.exception_yn           := upper(x_clev_rec.exception_yn);
         x_clev_rec.item_to_price_yn       := upper(x_clev_rec.item_to_price_yn);
         x_clev_rec.price_basis_yn         := upper(x_clev_rec.price_basis_yn);
         x_clev_rec.config_complete_yn     := upper(x_clev_rec.config_complete_yn);
         x_clev_rec.config_valid_yn        := upper(x_clev_rec.config_valid_yn);
         x_clev_rec.config_item_type       := upper(x_clev_rec.config_item_type);
         /*********************** END HAND-CODED ********************************/
      
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('14700: Entered insert_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                g_pkg_name,
                                                p_init_msg_list,
                                                l_api_version,
                                                p_api_version,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_clev_rec := null_out_defaults(p_clev_rec);
      -- Set primary key value
      l_clev_rec.id := get_seq_id;
      --- Setting item attributes
      l_return_status := set_attributes(l_clev_rec, -- IN
                                        l_def_clev_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      /************************ HAND-CODED ***************************/
      IF (l_clev_rec.line_number IS NULL) THEN
         get_next_line_number(p_chr_id        => l_clev_rec.chr_id,
                              p_cle_id        => l_clev_rec.cle_id,
                              x_return_status => l_return_status,
                              x_line_number   => l_def_clev_rec.line_number);
         IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE okc_api.g_exception_unexpected_error;
         END IF;
      ELSE
         l_def_clev_rec.line_number := l_clev_rec.line_number;
      END IF;
   
      /*********************** END HAND-CODED ************************/
      l_def_clev_rec := fill_who_columns(l_def_clev_rec);
   
      IF p_clev_rec.validate_yn = 'Y' THEN
         ---Bug#3150149
         --- Validate all non-missing attributes (Item Level Validation)
         l_return_status := validate_attributes(l_def_clev_rec);
      END IF;
   
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_return_status := validate_record(l_def_clev_rec);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --------------------------------------
      -- Move VIEW record to "Child" records
      --------------------------------------
      migrate(l_def_clev_rec, l_cle_rec);
      migrate(l_def_clev_rec, l_okc_k_lines_tl_rec);
      --------------------------------------------
      -- Call the INSERT_ROW for each child record
      --------------------------------------------
      insert_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_cle_rec,
                 lx_cle_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      migrate(lx_cle_rec, l_def_clev_rec);
      insert_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_okc_k_lines_tl_rec,
                 lx_okc_k_lines_tl_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      migrate(lx_okc_k_lines_tl_rec, l_def_clev_rec);
      -- Set OUT values
      x_clev_rec := l_def_clev_rec;
   
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('14800: Exiting insert_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('14900: Exiting insert_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('15000: Exiting insert_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('15100: Exiting insert_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END insert_row;
   ----------------------------------------
   -- PL/SQL TBL insert_row for:CLEV_TBL --
   ----------------------------------------
   PROCEDURE insert_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_tbl      IN clev_tbl_type,
                        x_clev_tbl      OUT NOCOPY clev_tbl_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_tbl_insert_row';
      l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      i                NUMBER := 0;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('15200: Entered insert_row', 2);
      END IF;
   
      okc_api.init_msg_list(p_init_msg_list);
      -- Make sure PL/SQL table has records in it before passing
      IF (p_clev_tbl.COUNT > 0) THEN
         i := p_clev_tbl.FIRST;
         LOOP
            insert_row(p_api_version   => p_api_version,
                       p_init_msg_list => okc_api.g_false,
                       x_return_status => x_return_status,
                       x_msg_count     => x_msg_count,
                       x_msg_data      => x_msg_data,
                       p_clev_rec      => p_clev_tbl(i),
                       x_clev_rec      => x_clev_tbl(i));
         
            -- store the highest degree of error
            IF x_return_status <> okc_api.g_ret_sts_success THEN
               IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                  l_overall_status := x_return_status;
               END IF;
            END IF;
         
            EXIT WHEN(i = p_clev_tbl.LAST);
            i := p_clev_tbl.NEXT(i);
         END LOOP;
         -- return overall status
         x_return_status := l_overall_status;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('15300: Exiting insert_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('15400: Exiting insert_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('15500: Exiting insert_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('15600: Exiting insert_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END insert_row;

   ---------------------------------------------------------------------------
   -- PROCEDURE lock_row
   ---------------------------------------------------------------------------
   --------------------------------
   -- lock_row for:OKC_K_LINES_B --
   --------------------------------
   PROCEDURE lock_row(p_init_msg_list IN VARCHAR2,
                      x_return_status OUT NOCOPY VARCHAR2,
                      x_msg_count     OUT NOCOPY NUMBER,
                      x_msg_data      OUT NOCOPY VARCHAR2,
                      p_cle_rec       IN cle_rec_type) IS
   
      e_resource_busy EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_resource_busy, -00054);
      CURSOR lock_csr(p_cle_rec IN cle_rec_type) IS
         SELECT object_version_number
           FROM okc_k_lines_b
          WHERE id = p_cle_rec.id AND
                object_version_number = p_cle_rec.object_version_number
            FOR UPDATE OF object_version_number NOWAIT;
   
      CURSOR lchk_csr(p_cle_rec IN cle_rec_type) IS
         SELECT object_version_number
           FROM okc_k_lines_b
          WHERE id = p_cle_rec.id;
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'B_lock_row';
      l_return_status          VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_object_version_number  okc_k_lines_b.object_version_number%TYPE;
      lc_object_version_number okc_k_lines_b.object_version_number%TYPE;
      l_row_notfound           BOOLEAN := FALSE;
      lc_row_notfound          BOOLEAN := FALSE;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('15700: Entered lock_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      BEGIN
      
         IF (l_debug = 'Y') THEN
            okc_debug.set_indentation('OKC_CLE_PVT');
            okc_debug.log('15800: Entered lock_row', 2);
         END IF;
      
         OPEN lock_csr(p_cle_rec);
         FETCH lock_csr
            INTO l_object_version_number;
         l_row_notfound := lock_csr%NOTFOUND;
         CLOSE lock_csr;
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('15900: Leaving lock_row', 2);
            okc_debug.reset_indentation;
         END IF;
      
      EXCEPTION
         WHEN e_resource_busy THEN
         
            IF (l_debug = 'Y') THEN
               okc_debug.log('16000: Exiting lock_row:E_Resource_Busy Exception',
                             2);
               okc_debug.reset_indentation;
            END IF;
         
            IF (lock_csr%ISOPEN) THEN
               CLOSE lock_csr;
            END IF;
            okc_api.set_message(g_fnd_app, g_form_unable_to_reserve_rec);
            RAISE app_exceptions.record_lock_exception;
      END;
   
      IF (l_row_notfound) THEN
         OPEN lchk_csr(p_cle_rec);
         FETCH lchk_csr
            INTO lc_object_version_number;
         lc_row_notfound := lchk_csr%NOTFOUND;
         CLOSE lchk_csr;
      END IF;
      IF (lc_row_notfound) THEN
         okc_api.set_message(g_fnd_app, g_form_record_deleted);
         RAISE okc_api.g_exception_error;
      ELSIF lc_object_version_number > p_cle_rec.object_version_number THEN
         okc_api.set_message(g_fnd_app, g_form_record_changed);
         RAISE okc_api.g_exception_error;
      ELSIF lc_object_version_number <> p_cle_rec.object_version_number THEN
         okc_api.set_message(g_fnd_app, g_form_record_changed);
         RAISE okc_api.g_exception_error;
      ELSIF lc_object_version_number = -1 THEN
         okc_api.set_message(g_app_name, g_record_logically_deleted);
         RAISE okc_api.g_exception_error;
      END IF;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('16100: Leaving lock_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('16200: Exiting lock_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('16300: Exiting lock_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('16400: Exiting lock_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END lock_row;
   ---------------------------------
   -- lock_row for:OKC_K_LINES_TL --
   ---------------------------------
   PROCEDURE lock_row(p_init_msg_list      IN VARCHAR2,
                      x_return_status      OUT NOCOPY VARCHAR2,
                      x_msg_count          OUT NOCOPY NUMBER,
                      x_msg_data           OUT NOCOPY VARCHAR2,
                      p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type) IS
   
      e_resource_busy EXCEPTION;
      PRAGMA EXCEPTION_INIT(e_resource_busy, -00054);
      CURSOR lock_csr(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type) IS
         SELECT *
           FROM okc_k_lines_tl
          WHERE id = p_okc_k_lines_tl_rec.id
            FOR UPDATE NOWAIT;
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'TL_lock_row';
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_lock_var      lock_csr%ROWTYPE;
      l_row_notfound  BOOLEAN := FALSE;
      lc_row_notfound BOOLEAN := FALSE;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('16500: Entered lock_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      BEGIN
      
         IF (l_debug = 'Y') THEN
            okc_debug.set_indentation('OKC_CLE_PVT');
            okc_debug.log('16600: Entered lock_row', 2);
         END IF;
      
         OPEN lock_csr(p_okc_k_lines_tl_rec);
         FETCH lock_csr
            INTO l_lock_var;
         l_row_notfound := lock_csr%NOTFOUND;
         CLOSE lock_csr;
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('16700: Exiting lock_row', 2);
            okc_debug.reset_indentation;
         END IF;
      
      EXCEPTION
         WHEN e_resource_busy THEN
         
            IF (l_debug = 'Y') THEN
               okc_debug.log('16800: Exiting lock_row:E_Resource_Busy Exception',
                             2);
               okc_debug.reset_indentation;
            END IF;
         
            IF (lock_csr%ISOPEN) THEN
               CLOSE lock_csr;
            END IF;
            okc_api.set_message(g_fnd_app, g_form_unable_to_reserve_rec);
            RAISE app_exceptions.record_lock_exception;
      END;
   
      IF (l_row_notfound) THEN
         okc_api.set_message(g_fnd_app, g_form_record_deleted);
         RAISE okc_api.g_exception_error;
      END IF;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('16900: Exiting lock_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('17000: Exiting lock_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('17100: Exiting lock_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('17200: Exiting lock_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END lock_row;
   --------------------------------
   -- lock_row for:OKC_K_LINES_V --
   --------------------------------
   PROCEDURE lock_row(p_api_version   IN NUMBER,
                      p_init_msg_list IN VARCHAR2,
                      x_return_status OUT NOCOPY VARCHAR2,
                      x_msg_count     OUT NOCOPY NUMBER,
                      x_msg_data      OUT NOCOPY VARCHAR2,
                      p_clev_rec      IN clev_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_lock_row';
      l_return_status      VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_cle_rec            cle_rec_type;
      l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('17300: Entered lock_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                g_pkg_name,
                                                p_init_msg_list,
                                                l_api_version,
                                                p_api_version,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --------------------------------------
      -- Move VIEW record to "Child" records
      --------------------------------------
      migrate(p_clev_rec, l_cle_rec);
      migrate(p_clev_rec, l_okc_k_lines_tl_rec);
      --------------------------------------------
      -- Call the LOCK_ROW for each child record
      --------------------------------------------
      lock_row(p_init_msg_list,
               x_return_status,
               x_msg_count,
               x_msg_data,
               l_cle_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      lock_row(p_init_msg_list,
               x_return_status,
               x_msg_count,
               x_msg_data,
               l_okc_k_lines_tl_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('17400: Exiting lock_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('17500: Exiting lock_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('17600: Exiting lock_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('17700: Exiting lock_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END lock_row;
   --------------------------------------
   -- PL/SQL TBL lock_row for:CLEV_TBL --
   --------------------------------------
   PROCEDURE lock_row(p_api_version   IN NUMBER,
                      p_init_msg_list IN VARCHAR2,
                      x_return_status OUT NOCOPY VARCHAR2,
                      x_msg_count     OUT NOCOPY NUMBER,
                      x_msg_data      OUT NOCOPY VARCHAR2,
                      p_clev_tbl      IN clev_tbl_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_tbl_lock_row';
      l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      i                NUMBER := 0;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('17800: Entered lock_row', 2);
      END IF;
   
      okc_api.init_msg_list(p_init_msg_list);
      -- Make sure PL/SQL table has records in it before passing
      IF (p_clev_tbl.COUNT > 0) THEN
         i := p_clev_tbl.FIRST;
         LOOP
            lock_row(p_api_version   => p_api_version,
                     p_init_msg_list => okc_api.g_false,
                     x_return_status => x_return_status,
                     x_msg_count     => x_msg_count,
                     x_msg_data      => x_msg_data,
                     p_clev_rec      => p_clev_tbl(i));
         
            -- store the highest degree of error
            IF x_return_status <> okc_api.g_ret_sts_success THEN
               IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                  l_overall_status := x_return_status;
               END IF;
            END IF;
         
            EXIT WHEN(i = p_clev_tbl.LAST);
            i := p_clev_tbl.NEXT(i);
         END LOOP;
         -- return overall status
         x_return_status := l_overall_status;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('17900: Exiting lock_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18000: Exiting lock_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18100: Exiting lock_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18200: Exiting lock_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END lock_row;

   ---------------------------------------------------------------------------
   -- PROCEDURE update_row
   ---------------------------------------------------------------------------
   ----------------------------------
   -- update_row for:OKC_K_LINES_B --
   ----------------------------------
   PROCEDURE update_row(p_init_msg_list     IN VARCHAR2,
                        x_return_status     OUT NOCOPY VARCHAR2,
                        x_msg_count         OUT NOCOPY NUMBER,
                        x_msg_data          OUT NOCOPY VARCHAR2,
                        p_restricted_update IN VARCHAR2,
                        p_cle_rec           IN cle_rec_type,
                        x_cle_rec           OUT NOCOPY cle_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'B_update_row';
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_cle_rec       cle_rec_type := p_cle_rec;
      l_def_cle_rec   cle_rec_type;
      l_row_notfound  BOOLEAN := TRUE;
      ----------------------------------
      -- FUNCTION populate_new_record --
      ----------------------------------
      FUNCTION populate_new_record(p_cle_rec IN cle_rec_type,
                                   x_cle_rec OUT NOCOPY cle_rec_type)
         RETURN VARCHAR2 IS
         l_cle_rec       cle_rec_type;
         l_row_notfound  BOOLEAN := TRUE;
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         IF (l_debug = 'Y') THEN
            okc_debug.set_indentation('OKC_CLE_PVT');
            okc_debug.log('18300: Entered populate_new_record', 2);
         END IF;
      
         x_cle_rec := p_cle_rec;
         -- Get current database values
         l_cle_rec := get_rec(p_cle_rec, l_row_notfound);
         IF (l_row_notfound) THEN
            l_return_status := okc_api.g_ret_sts_unexp_error;
         END IF;
         IF (x_cle_rec.id = okc_api.g_miss_num) THEN
            x_cle_rec.id := l_cle_rec.id;
         END IF;
         IF (x_cle_rec.line_number = okc_api.g_miss_char) THEN
            x_cle_rec.line_number := l_cle_rec.line_number;
         END IF;
         IF (x_cle_rec.chr_id = okc_api.g_miss_num) THEN
            x_cle_rec.chr_id := l_cle_rec.chr_id;
         END IF;
         IF (x_cle_rec.cle_id = okc_api.g_miss_num) THEN
            x_cle_rec.cle_id := l_cle_rec.cle_id;
         END IF;
         IF (x_cle_rec.dnz_chr_id = okc_api.g_miss_num) THEN
            x_cle_rec.dnz_chr_id := l_cle_rec.dnz_chr_id;
         END IF;
         IF (x_cle_rec.display_sequence = okc_api.g_miss_num) THEN
            x_cle_rec.display_sequence := l_cle_rec.display_sequence;
         END IF;
         IF (x_cle_rec.sts_code = okc_api.g_miss_char) THEN
            x_cle_rec.sts_code := l_cle_rec.sts_code;
         END IF;
         IF (x_cle_rec.trn_code = okc_api.g_miss_char) THEN
            x_cle_rec.trn_code := l_cle_rec.trn_code;
         END IF;
         IF (x_cle_rec.lse_id = okc_api.g_miss_num) THEN
            x_cle_rec.lse_id := l_cle_rec.lse_id;
         END IF;
         IF (x_cle_rec.exception_yn = okc_api.g_miss_char) THEN
            x_cle_rec.exception_yn := l_cle_rec.exception_yn;
         END IF;
         IF (x_cle_rec.object_version_number = okc_api.g_miss_num) THEN
            x_cle_rec.object_version_number := l_cle_rec.object_version_number;
         END IF;
         IF (x_cle_rec.created_by = okc_api.g_miss_num) THEN
            x_cle_rec.created_by := l_cle_rec.created_by;
         END IF;
         IF (x_cle_rec.creation_date = okc_api.g_miss_date) THEN
            x_cle_rec.creation_date := l_cle_rec.creation_date;
         END IF;
         IF (x_cle_rec.last_updated_by = okc_api.g_miss_num) THEN
            x_cle_rec.last_updated_by := l_cle_rec.last_updated_by;
         END IF;
         IF (x_cle_rec.last_update_date = okc_api.g_miss_date) THEN
            x_cle_rec.last_update_date := l_cle_rec.last_update_date;
         END IF;
         IF (x_cle_rec.hidden_ind = okc_api.g_miss_char) THEN
            x_cle_rec.hidden_ind := l_cle_rec.hidden_ind;
         END IF;
         IF (x_cle_rec.price_unit = okc_api.g_miss_num) THEN
            x_cle_rec.price_unit := l_cle_rec.price_unit;
         END IF;
         IF (x_cle_rec.price_unit_percent = okc_api.g_miss_num) THEN
            x_cle_rec.price_unit_percent := l_cle_rec.price_unit_percent;
         END IF;
         IF (x_cle_rec.price_negotiated = okc_api.g_miss_num) THEN
            x_cle_rec.price_negotiated := l_cle_rec.price_negotiated;
         END IF;
         IF (x_cle_rec.price_negotiated_renewed = okc_api.g_miss_num) THEN
            x_cle_rec.price_negotiated_renewed := l_cle_rec.price_negotiated_renewed;
         END IF;
         IF (x_cle_rec.price_level_ind = okc_api.g_miss_char) THEN
            x_cle_rec.price_level_ind := l_cle_rec.price_level_ind;
         END IF;
         IF (x_cle_rec.invoice_line_level_ind = okc_api.g_miss_char) THEN
            x_cle_rec.invoice_line_level_ind := l_cle_rec.invoice_line_level_ind;
         END IF;
         IF (x_cle_rec.dpas_rating = okc_api.g_miss_char) THEN
            x_cle_rec.dpas_rating := l_cle_rec.dpas_rating;
         END IF;
         IF (x_cle_rec.template_used = okc_api.g_miss_char) THEN
            x_cle_rec.template_used := l_cle_rec.template_used;
         END IF;
         IF (x_cle_rec.price_type = okc_api.g_miss_char) THEN
            x_cle_rec.price_type := l_cle_rec.price_type;
         END IF;
         IF (x_cle_rec.currency_code = okc_api.g_miss_char) THEN
            x_cle_rec.currency_code := l_cle_rec.currency_code;
         END IF;
         IF (x_cle_rec.currency_code_renewed = okc_api.g_miss_char) THEN
            x_cle_rec.currency_code_renewed := l_cle_rec.currency_code_renewed;
         END IF;
         IF (x_cle_rec.last_update_login = okc_api.g_miss_num) THEN
            x_cle_rec.last_update_login := l_cle_rec.last_update_login;
         END IF;
         IF (x_cle_rec.date_terminated = okc_api.g_miss_date) THEN
            x_cle_rec.date_terminated := l_cle_rec.date_terminated;
         END IF;
         --NPALEPU
         --24-JUN-2005
         --ANNUALIZED AMOUNTS PROJECT
         --ADDED CONDITION TO CALCULATE THE ANNUALIZED_FACTOR VALUE
         IF ((x_cle_rec.start_date = okc_api.g_miss_date) AND
            (x_cle_rec.end_date = okc_api.g_miss_date)) THEN
         
            x_cle_rec.annualized_factor := l_cle_rec.annualized_factor;
         
         ELSE
         
            IF x_cle_rec.lse_id IN
               (1, 12, 14, 19, 46, 7, 8, 9, 10, 11, 13, 18, 25, 35) THEN
            
               BEGIN
               
                  SELECT (add_months(x_cle_rec.start_date,
                                     (nyears + 1) * 12) -
                         x_cle_rec.start_date -
                         decode(add_months(x_cle_rec.end_date, -12),
                                 (x_cle_rec.end_date - 366),
                                 0,
                                 decode(add_months(x_cle_rec.start_date,
                                                   (nyears + 1) * 12) -
                                        add_months(x_cle_rec.start_date,
                                                   nyears * 12),
                                        366,
                                        1,
                                        0))) / (nyears + 1) /
                         (x_cle_rec.end_date - x_cle_rec.start_date + 1)
                    INTO x_cle_rec.annualized_factor
                    FROM (SELECT trunc(months_between(x_cle_rec.end_date,
                                                      x_cle_rec.start_date) / 12) nyears
                            FROM dual) dual;
               
               EXCEPTION
               
                  WHEN no_data_found THEN
                  
                     x_cle_rec.annualized_factor := 0;
                  
                  WHEN OTHERS THEN
                  
                     x_cle_rec.annualized_factor := 0;
               END;
            
            ELSE
               x_cle_rec.annualized_factor := 0;
            
            END IF; /* IF <x_cle_rec.lse_id in (1,12,14,19,46,7,8,9,10,11,13,18,25,35)> */
         
         END IF; /* IF <((x_cle_rec.start_date = OKC_API.G_MISS_DATE) AND (x_cle_rec.end_date = OKC_API.G_MISS_DATE))>  */
         --END NPALEPU
         IF (x_cle_rec.start_date = okc_api.g_miss_date) THEN
            x_cle_rec.start_date := l_cle_rec.start_date;
         END IF;
         IF (x_cle_rec.end_date = okc_api.g_miss_date) THEN
            x_cle_rec.end_date := l_cle_rec.end_date;
         END IF;
         IF (x_cle_rec.date_renewed = okc_api.g_miss_date) THEN
            x_cle_rec.date_renewed := l_cle_rec.date_renewed;
         END IF;
         IF (x_cle_rec.upg_orig_system_ref = okc_api.g_miss_char) THEN
            x_cle_rec.upg_orig_system_ref := l_cle_rec.upg_orig_system_ref;
         END IF;
         IF (x_cle_rec.upg_orig_system_ref_id = okc_api.g_miss_num) THEN
            x_cle_rec.upg_orig_system_ref_id := l_cle_rec.upg_orig_system_ref_id;
         END IF;
         IF (x_cle_rec.orig_system_source_code = okc_api.g_miss_char) THEN
            x_cle_rec.orig_system_source_code := l_cle_rec.orig_system_source_code;
         END IF;
         IF (x_cle_rec.orig_system_id1 = okc_api.g_miss_num) THEN
            x_cle_rec.orig_system_id1 := l_cle_rec.orig_system_id1;
         END IF;
         IF (x_cle_rec.orig_system_reference1 = okc_api.g_miss_char) THEN
            x_cle_rec.orig_system_reference1 := l_cle_rec.orig_system_reference1;
         END IF;
         IF (x_cle_rec.program_application_id = okc_api.g_miss_num) THEN
            x_cle_rec.program_application_id := l_cle_rec.program_application_id;
         END IF;
         IF (x_cle_rec.program_id = okc_api.g_miss_num) THEN
            x_cle_rec.program_id := l_cle_rec.program_id;
         END IF;
         IF (x_cle_rec.program_update_date = okc_api.g_miss_date) THEN
            x_cle_rec.program_update_date := l_cle_rec.program_update_date;
         END IF;
         IF (x_cle_rec.request_id = okc_api.g_miss_num) THEN
            x_cle_rec.request_id := l_cle_rec.request_id;
         END IF;
         IF (x_cle_rec.price_list_id = okc_api.g_miss_num) THEN
            x_cle_rec.price_list_id := l_cle_rec.price_list_id;
         END IF;
         IF (x_cle_rec.pricing_date = okc_api.g_miss_date) THEN
            x_cle_rec.pricing_date := l_cle_rec.pricing_date;
         END IF;
         IF (x_cle_rec.price_list_line_id = okc_api.g_miss_num) THEN
            x_cle_rec.price_list_line_id := l_cle_rec.price_list_line_id;
         END IF;
         IF (x_cle_rec.line_list_price = okc_api.g_miss_num) THEN
            x_cle_rec.line_list_price := l_cle_rec.line_list_price;
         END IF;
         IF (x_cle_rec.item_to_price_yn = okc_api.g_miss_char) THEN
            x_cle_rec.item_to_price_yn := l_cle_rec.item_to_price_yn;
         END IF;
         IF (x_cle_rec.price_basis_yn = okc_api.g_miss_char) THEN
            x_cle_rec.price_basis_yn := l_cle_rec.price_basis_yn;
         END IF;
         IF (x_cle_rec.config_header_id = okc_api.g_miss_num) THEN
            x_cle_rec.config_header_id := l_cle_rec.config_header_id;
         END IF;
         IF (x_cle_rec.config_revision_number = okc_api.g_miss_num) THEN
            x_cle_rec.config_revision_number := l_cle_rec.config_revision_number;
         END IF;
         IF (x_cle_rec.config_complete_yn = okc_api.g_miss_char) THEN
            x_cle_rec.config_complete_yn := l_cle_rec.config_complete_yn;
         END IF;
         IF (x_cle_rec.config_valid_yn = okc_api.g_miss_char) THEN
            x_cle_rec.config_valid_yn := l_cle_rec.config_valid_yn;
         END IF;
         IF (x_cle_rec.config_top_model_line_id = okc_api.g_miss_num) THEN
            x_cle_rec.config_top_model_line_id := l_cle_rec.config_top_model_line_id;
         END IF;
         IF (x_cle_rec.config_item_type = okc_api.g_miss_char) THEN
            x_cle_rec.config_item_type := l_cle_rec.config_item_type;
         END IF;
         ---Bug.No.-1942374
         IF (x_cle_rec.config_item_id = okc_api.g_miss_num) THEN
            x_cle_rec.config_item_id := l_cle_rec.config_item_id;
         END IF;
         ---Bug.No.-1942374
         IF (x_cle_rec.attribute_category = okc_api.g_miss_char) THEN
            x_cle_rec.attribute_category := l_cle_rec.attribute_category;
         END IF;
         IF (x_cle_rec.attribute1 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute1 := l_cle_rec.attribute1;
         END IF;
         IF (x_cle_rec.attribute2 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute2 := l_cle_rec.attribute2;
         END IF;
         IF (x_cle_rec.attribute3 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute3 := l_cle_rec.attribute3;
         END IF;
         IF (x_cle_rec.attribute4 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute4 := l_cle_rec.attribute4;
         END IF;
         IF (x_cle_rec.attribute5 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute5 := l_cle_rec.attribute5;
         END IF;
         IF (x_cle_rec.attribute6 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute6 := l_cle_rec.attribute6;
         END IF;
         IF (x_cle_rec.attribute7 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute7 := l_cle_rec.attribute7;
         END IF;
         IF (x_cle_rec.attribute8 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute8 := l_cle_rec.attribute8;
         END IF;
         IF (x_cle_rec.attribute9 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute9 := l_cle_rec.attribute9;
         END IF;
         IF (x_cle_rec.attribute10 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute10 := l_cle_rec.attribute10;
         END IF;
         IF (x_cle_rec.attribute11 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute11 := l_cle_rec.attribute11;
         END IF;
         IF (x_cle_rec.attribute12 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute12 := l_cle_rec.attribute12;
         END IF;
         IF (x_cle_rec.attribute13 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute13 := l_cle_rec.attribute13;
         END IF;
         IF (x_cle_rec.attribute14 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute14 := l_cle_rec.attribute14;
         END IF;
         IF (x_cle_rec.attribute15 = okc_api.g_miss_char) THEN
            x_cle_rec.attribute15 := l_cle_rec.attribute15;
         END IF;
         IF (x_cle_rec.service_item_yn = okc_api.g_miss_char) THEN
            x_cle_rec.service_item_yn := l_cle_rec.service_item_yn;
         END IF;
         --new columns for price hold
         IF (x_cle_rec.ph_pricing_type = okc_api.g_miss_char) THEN
            x_cle_rec.ph_pricing_type := l_cle_rec.ph_pricing_type;
         END IF;
         IF (x_cle_rec.ph_price_break_basis = okc_api.g_miss_char) THEN
            x_cle_rec.ph_price_break_basis := l_cle_rec.ph_price_break_basis;
         END IF;
         IF (x_cle_rec.ph_min_qty = okc_api.g_miss_num) THEN
            x_cle_rec.ph_min_qty := l_cle_rec.ph_min_qty;
         END IF;
         IF (x_cle_rec.ph_min_amt = okc_api.g_miss_num) THEN
            x_cle_rec.ph_min_amt := l_cle_rec.ph_min_amt;
         END IF;
         IF (x_cle_rec.ph_qp_reference_id = okc_api.g_miss_num) THEN
            x_cle_rec.ph_qp_reference_id := l_cle_rec.ph_qp_reference_id;
         END IF;
         IF (x_cle_rec.ph_value = okc_api.g_miss_num) THEN
            x_cle_rec.ph_value := l_cle_rec.ph_value;
         END IF;
         IF (x_cle_rec.ph_enforce_price_list_yn = okc_api.g_miss_char) THEN
            x_cle_rec.ph_enforce_price_list_yn := l_cle_rec.ph_enforce_price_list_yn;
         END IF;
         IF (x_cle_rec.ph_adjustment = okc_api.g_miss_num) THEN
            x_cle_rec.ph_adjustment := l_cle_rec.ph_adjustment;
         END IF;
         IF (x_cle_rec.ph_integrated_with_qp = okc_api.g_miss_char) THEN
            x_cle_rec.ph_integrated_with_qp := l_cle_rec.ph_integrated_with_qp;
         END IF;
         -- new  columns to replace rules
         IF (x_cle_rec.cust_acct_id = okc_api.g_miss_num) THEN
            x_cle_rec.cust_acct_id := l_cle_rec.cust_acct_id;
         END IF;
         IF (x_cle_rec.bill_to_site_use_id = okc_api.g_miss_num) THEN
            x_cle_rec.bill_to_site_use_id := l_cle_rec.bill_to_site_use_id;
         END IF;
         IF (x_cle_rec.inv_rule_id = okc_api.g_miss_num) THEN
            x_cle_rec.inv_rule_id := l_cle_rec.inv_rule_id;
         END IF;
         IF (x_cle_rec.line_renewal_type_code = okc_api.g_miss_char) THEN
            x_cle_rec.line_renewal_type_code := l_cle_rec.line_renewal_type_code;
         END IF;
         IF (x_cle_rec.ship_to_site_use_id = okc_api.g_miss_num) THEN
            x_cle_rec.ship_to_site_use_id := l_cle_rec.ship_to_site_use_id;
         END IF;
         IF (x_cle_rec.payment_term_id = okc_api.g_miss_num) THEN
            x_cle_rec.payment_term_id := l_cle_rec.payment_term_id;
         END IF;
         ---- line Level Cancellation ---
         IF (x_cle_rec.date_cancelled = okc_api.g_miss_date) THEN
            x_cle_rec.date_cancelled := l_cle_rec.date_cancelled;
         END IF;
         /* IF (x_cle_rec.canc_reason_code = OKC_API.G_MISS_CHAR) THEN
           x_cle_rec.canc_reason_code := l_cle_rec.canc_reason_code;
         END IF; */
         IF (x_cle_rec.term_cancel_source = okc_api.g_miss_char) THEN
            x_cle_rec.term_cancel_source := l_cle_rec.term_cancel_source;
         END IF;
         IF (x_cle_rec.cancelled_amount = okc_api.g_miss_num) THEN
            x_cle_rec.cancelled_amount := l_cle_rec.cancelled_amount;
         END IF;
         IF (x_cle_rec.payment_instruction_type = okc_api.g_miss_char) THEN
            x_cle_rec.payment_instruction_type := l_cle_rec.payment_instruction_type;
         END IF;
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18350: Leaving  populate_new_record', 2);
            okc_debug.reset_indentation;
         END IF;
      
         RETURN(l_return_status);
      
      END populate_new_record;
      --------------------------------------
      -- Set_Attributes for:OKC_K_LINES_B --
      --------------------------------------
      FUNCTION set_attributes(p_cle_rec IN cle_rec_type,
                              x_cle_rec OUT NOCOPY cle_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_cle_rec := p_cle_rec;
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('18500: Entered update_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --- Setting item attributes
      l_return_status := set_attributes(p_cle_rec, -- IN
                                        l_cle_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_return_status := populate_new_record(l_cle_rec, l_def_cle_rec);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
   
      UPDATE okc_k_lines_b
         SET line_number              = l_def_cle_rec.line_number,
             chr_id                   = l_def_cle_rec.chr_id,
             cle_id                   = l_def_cle_rec.cle_id,
             dnz_chr_id               = l_def_cle_rec.dnz_chr_id,
             display_sequence         = l_def_cle_rec.display_sequence,
             sts_code                 = l_def_cle_rec.sts_code,
             trn_code                 = l_def_cle_rec.trn_code,
             lse_id                   = l_def_cle_rec.lse_id,
             exception_yn             = l_def_cle_rec.exception_yn,
             object_version_number    = l_def_cle_rec.object_version_number,
             created_by               = l_def_cle_rec.created_by,
             creation_date            = l_def_cle_rec.creation_date,
             last_updated_by          = l_def_cle_rec.last_updated_by,
             last_update_date         = l_def_cle_rec.last_update_date,
             hidden_ind               = l_def_cle_rec.hidden_ind,
             price_unit               = l_def_cle_rec.price_unit,
             price_unit_percent       = l_def_cle_rec.price_unit_percent,
             price_negotiated         = l_def_cle_rec.price_negotiated,
             price_negotiated_renewed = l_def_cle_rec.price_negotiated_renewed,
             price_level_ind          = l_def_cle_rec.price_level_ind,
             invoice_line_level_ind   = l_def_cle_rec.invoice_line_level_ind,
             dpas_rating              = l_def_cle_rec.dpas_rating,
             template_used            = l_def_cle_rec.template_used,
             price_type               = l_def_cle_rec.price_type,
             currency_code            = l_def_cle_rec.currency_code,
             currency_code_renewed    = l_def_cle_rec.currency_code_renewed,
             last_update_login        = l_def_cle_rec.last_update_login,
             date_terminated          = l_def_cle_rec.date_terminated,
             start_date               = l_def_cle_rec.start_date,
             end_date                 = l_def_cle_rec.end_date,
             date_renewed             = l_def_cle_rec.date_renewed,
             upg_orig_system_ref      = l_def_cle_rec.upg_orig_system_ref,
             upg_orig_system_ref_id   = l_def_cle_rec.upg_orig_system_ref_id,
             orig_system_source_code  = l_def_cle_rec.orig_system_source_code,
             orig_system_id1          = l_def_cle_rec.orig_system_id1,
             orig_system_reference1   = l_def_cle_rec.orig_system_reference1,
             program_id               = nvl(decode(fnd_global.conc_program_id,
                                                   -1,
                                                   NULL,
                                                   fnd_global.conc_program_id),
                                            l_def_cle_rec.program_id),
             request_id               = nvl(decode(fnd_global.conc_request_id,
                                                   -1,
                                                   NULL,
                                                   fnd_global.conc_request_id),
                                            l_def_cle_rec.request_id),
             program_update_date      = decode(decode(fnd_global.conc_request_id,
                                                      -1,
                                                      NULL,
                                                      SYSDATE),
                                               NULL,
                                               l_def_cle_rec.program_update_date,
                                               SYSDATE),
             program_application_id   = nvl(decode(fnd_global.prog_appl_id,
                                                   -1,
                                                   NULL,
                                                   fnd_global.prog_appl_id),
                                            l_def_cle_rec.program_application_id),
             price_list_id            = l_def_cle_rec.price_list_id,
             pricing_date             = l_def_cle_rec.pricing_date,
             price_list_line_id       = l_def_cle_rec.price_list_line_id,
             line_list_price          = l_def_cle_rec.line_list_price,
             item_to_price_yn         = l_def_cle_rec.item_to_price_yn,
             price_basis_yn           = l_def_cle_rec.price_basis_yn,
             config_header_id         = l_def_cle_rec.config_header_id,
             config_revision_number   = l_def_cle_rec.config_revision_number,
             config_complete_yn       = l_def_cle_rec.config_complete_yn,
             config_valid_yn          = l_def_cle_rec.config_valid_yn,
             config_top_model_line_id = l_def_cle_rec.config_top_model_line_id,
             config_item_type         = l_def_cle_rec.config_item_type,
             config_item_id           = l_def_cle_rec.config_item_id,
             attribute_category       = l_def_cle_rec.attribute_category,
             attribute1               = l_def_cle_rec.attribute1,
             attribute2               = l_def_cle_rec.attribute2,
             attribute3               = l_def_cle_rec.attribute3,
             attribute4               = l_def_cle_rec.attribute4,
             attribute5               = l_def_cle_rec.attribute5,
             attribute6               = l_def_cle_rec.attribute6,
             attribute7               = l_def_cle_rec.attribute7,
             attribute8               = l_def_cle_rec.attribute8,
             attribute9               = l_def_cle_rec.attribute9,
             attribute10              = l_def_cle_rec.attribute10,
             attribute11              = l_def_cle_rec.attribute11,
             attribute12              = l_def_cle_rec.attribute12,
             attribute13              = l_def_cle_rec.attribute13,
             attribute14              = l_def_cle_rec.attribute14,
             attribute15              = l_def_cle_rec.attribute15,
             service_item_yn          = l_def_cle_rec.service_item_yn,
             --new columns for price hold
             ph_pricing_type          = l_def_cle_rec.ph_pricing_type,
             ph_price_break_basis     = l_def_cle_rec.ph_price_break_basis,
             ph_min_qty               = l_def_cle_rec.ph_min_qty,
             ph_min_amt               = l_def_cle_rec.ph_min_amt,
             ph_qp_reference_id       = l_def_cle_rec.ph_qp_reference_id,
             ph_value                 = l_def_cle_rec.ph_value,
             ph_enforce_price_list_yn = l_def_cle_rec.ph_enforce_price_list_yn,
             ph_adjustment            = l_def_cle_rec.ph_adjustment,
             ph_integrated_with_qp    = l_def_cle_rec.ph_integrated_with_qp,
             --new columns to replace rules
             cust_acct_id           = l_def_cle_rec.cust_acct_id,
             bill_to_site_use_id    = l_def_cle_rec.bill_to_site_use_id,
             inv_rule_id            = l_def_cle_rec.inv_rule_id,
             line_renewal_type_code = l_def_cle_rec.line_renewal_type_code,
             ship_to_site_use_id    = l_def_cle_rec.ship_to_site_use_id,
             payment_term_id        = l_def_cle_rec.payment_term_id,
             --NPALEPU on 03-JUN-2005 Added new column for Annualized Amounts
             annualized_factor = l_def_cle_rec.annualized_factor,
             --END NPALEPU
             --LINE LEVEL CANCELLATION--
             date_cancelled = l_def_cle_rec.date_cancelled,
             --canc_reason_code          = l_def_cle_rec.canc_reason_code,
             term_cancel_source = l_def_cle_rec.term_cancel_source,
             cancelled_amount   = l_def_cle_rec.cancelled_amount,
             --added by mchoudha 22-JUL
             payment_instruction_type = l_def_cle_rec.payment_instruction_type
       WHERE id = l_def_cle_rec.id;
   
      x_cle_rec := l_def_cle_rec;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('18600: Exiting update_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18700: Exiting update_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18800: Exiting update_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('18900: Exiting update_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END update_row;
   -----------------------------------
   -- update_row for:OKC_K_LINES_TL --
   -----------------------------------
   PROCEDURE update_row(p_init_msg_list      IN VARCHAR2,
                        x_return_status      OUT NOCOPY VARCHAR2,
                        x_msg_count          OUT NOCOPY NUMBER,
                        x_msg_data           OUT NOCOPY VARCHAR2,
                        p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                        x_okc_k_lines_tl_rec OUT NOCOPY okc_k_lines_tl_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'TL_update_row';
      l_return_status          VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_okc_k_lines_tl_rec     okc_k_lines_tl_rec_type := p_okc_k_lines_tl_rec;
      l_def_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
      l_row_notfound           BOOLEAN := TRUE;
      ----------------------------------
      -- FUNCTION populate_new_record --
      ----------------------------------
      FUNCTION populate_new_record(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                                   x_okc_k_lines_tl_rec OUT NOCOPY okc_k_lines_tl_rec_type)
         RETURN VARCHAR2 IS
         l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
         l_row_notfound       BOOLEAN := TRUE;
         l_return_status      VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         IF (l_debug = 'Y') THEN
            okc_debug.set_indentation('OKC_CLE_PVT');
            okc_debug.log('19000: Entered populate_new_record', 2);
         END IF;
      
         x_okc_k_lines_tl_rec := p_okc_k_lines_tl_rec;
         -- Get current database values
         l_okc_k_lines_tl_rec := get_rec(p_okc_k_lines_tl_rec,
                                         l_row_notfound);
         IF (l_row_notfound) THEN
            l_return_status := okc_api.g_ret_sts_unexp_error;
         END IF;
         IF (x_okc_k_lines_tl_rec.id = okc_api.g_miss_num) THEN
            x_okc_k_lines_tl_rec.id := l_okc_k_lines_tl_rec.id;
         END IF;
         IF (x_okc_k_lines_tl_rec.LANGUAGE = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.LANGUAGE := l_okc_k_lines_tl_rec.LANGUAGE;
         END IF;
         IF (x_okc_k_lines_tl_rec.source_lang = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.source_lang := l_okc_k_lines_tl_rec.source_lang;
         END IF;
         IF (x_okc_k_lines_tl_rec.sfwt_flag = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.sfwt_flag := l_okc_k_lines_tl_rec.sfwt_flag;
         END IF;
         IF (x_okc_k_lines_tl_rec.NAME = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.NAME := l_okc_k_lines_tl_rec.NAME;
         END IF;
         IF (x_okc_k_lines_tl_rec.comments = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.comments := l_okc_k_lines_tl_rec.comments;
         END IF;
         IF (x_okc_k_lines_tl_rec.item_description = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.item_description := l_okc_k_lines_tl_rec.item_description;
         END IF;
         IF (x_okc_k_lines_tl_rec.oke_boe_description = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.oke_boe_description := l_okc_k_lines_tl_rec.oke_boe_description;
         END IF;
         IF (x_okc_k_lines_tl_rec.cognomen = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.cognomen := l_okc_k_lines_tl_rec.cognomen;
         END IF;
         IF (x_okc_k_lines_tl_rec.block23text = okc_api.g_miss_char) THEN
            x_okc_k_lines_tl_rec.block23text := l_okc_k_lines_tl_rec.block23text;
         END IF;
         IF (x_okc_k_lines_tl_rec.created_by = okc_api.g_miss_num) THEN
            x_okc_k_lines_tl_rec.created_by := l_okc_k_lines_tl_rec.created_by;
         END IF;
         IF (x_okc_k_lines_tl_rec.creation_date = okc_api.g_miss_date) THEN
            x_okc_k_lines_tl_rec.creation_date := l_okc_k_lines_tl_rec.creation_date;
         END IF;
         IF (x_okc_k_lines_tl_rec.last_updated_by = okc_api.g_miss_num) THEN
            x_okc_k_lines_tl_rec.last_updated_by := l_okc_k_lines_tl_rec.last_updated_by;
         END IF;
         IF (x_okc_k_lines_tl_rec.last_update_date = okc_api.g_miss_date) THEN
            x_okc_k_lines_tl_rec.last_update_date := l_okc_k_lines_tl_rec.last_update_date;
         END IF;
         IF (x_okc_k_lines_tl_rec.last_update_login = okc_api.g_miss_num) THEN
            x_okc_k_lines_tl_rec.last_update_login := l_okc_k_lines_tl_rec.last_update_login;
         END IF;
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('19050: Leaving update_row', 2);
            okc_debug.reset_indentation;
         END IF;
      
         RETURN(l_return_status);
      
      END populate_new_record;
      ---------------------------------------
      -- Set_Attributes for:OKC_K_LINES_TL --
      ---------------------------------------
      FUNCTION set_attributes(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                              x_okc_k_lines_tl_rec OUT NOCOPY okc_k_lines_tl_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_okc_k_lines_tl_rec             := p_okc_k_lines_tl_rec;
         x_okc_k_lines_tl_rec.LANGUAGE    := okc_util.get_userenv_lang;
         x_okc_k_lines_tl_rec.source_lang := okc_util.get_userenv_lang;
      
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('19200: Entered update_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --- Setting item attributes
      l_return_status := set_attributes(p_okc_k_lines_tl_rec, -- IN
                                        l_okc_k_lines_tl_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_return_status := populate_new_record(l_okc_k_lines_tl_rec,
                                             l_def_okc_k_lines_tl_rec);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      UPDATE okc_k_lines_tl
         SET NAME                = l_def_okc_k_lines_tl_rec.NAME,
             comments            = l_def_okc_k_lines_tl_rec.comments,
             item_description    = l_def_okc_k_lines_tl_rec.item_description,
             oke_boe_description = l_def_okc_k_lines_tl_rec.oke_boe_description,
             cognomen            = l_def_okc_k_lines_tl_rec.cognomen,
             block23text         = l_def_okc_k_lines_tl_rec.block23text,
             source_lang         = l_def_okc_k_lines_tl_rec.source_lang,
             created_by          = l_def_okc_k_lines_tl_rec.created_by,
             creation_date       = l_def_okc_k_lines_tl_rec.creation_date,
             last_updated_by     = l_def_okc_k_lines_tl_rec.last_updated_by,
             last_update_date    = l_def_okc_k_lines_tl_rec.last_update_date,
             last_update_login   = l_def_okc_k_lines_tl_rec.last_update_login
       WHERE id = l_def_okc_k_lines_tl_rec.id AND
             userenv('LANG') IN (source_lang, LANGUAGE);
   
      UPDATE okc_k_lines_tl
         SET sfwt_flag = 'Y'
       WHERE id = l_def_okc_k_lines_tl_rec.id AND
             source_lang <> userenv('LANG');
   
      x_okc_k_lines_tl_rec := l_def_okc_k_lines_tl_rec;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('19300: Exiting update_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('19400: Exiting update_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('19500: Exiting update_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('19600: Exiting update_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END update_row;
   ----------------------------------
   -- update_row for:OKC_K_LINES_V --
   ----------------------------------
   PROCEDURE update_row(p_api_version       IN NUMBER,
                        p_init_msg_list     IN VARCHAR2,
                        x_return_status     OUT NOCOPY VARCHAR2,
                        x_msg_count         OUT NOCOPY NUMBER,
                        x_msg_data          OUT NOCOPY VARCHAR2,
                        p_restricted_update IN VARCHAR2,
                        p_clev_rec          IN clev_rec_type,
                        x_clev_rec          OUT NOCOPY clev_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_update_row';
      l_return_status       VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_clev_rec            clev_rec_type := p_clev_rec;
      l_def_clev_rec        clev_rec_type;
      l_okc_k_lines_tl_rec  okc_k_lines_tl_rec_type;
      lx_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
      l_cle_rec             cle_rec_type;
      lx_cle_rec            cle_rec_type;
      -------------------------------
      -- FUNCTION fill_who_columns --
      -------------------------------
      FUNCTION fill_who_columns(p_clev_rec IN clev_rec_type)
         RETURN clev_rec_type IS
         l_clev_rec clev_rec_type := p_clev_rec;
      BEGIN
      
         l_clev_rec.last_update_date  := SYSDATE;
         l_clev_rec.last_updated_by   := fnd_global.user_id;
         l_clev_rec.last_update_login := fnd_global.login_id;
         RETURN(l_clev_rec);
      
      END fill_who_columns;
      ----------------------------------
      -- FUNCTION populate_new_record --
      ----------------------------------
      FUNCTION populate_new_record(p_clev_rec IN clev_rec_type,
                                   x_clev_rec OUT NOCOPY clev_rec_type)
         RETURN VARCHAR2 IS
         l_clev_rec      clev_rec_type;
         l_row_notfound  BOOLEAN := TRUE;
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         IF (l_debug = 'Y') THEN
            okc_debug.set_indentation('OKC_CLE_PVT');
            okc_debug.log('19800: Entered populate_new_record', 2);
         END IF;
      
         x_clev_rec := p_clev_rec;
         -- Get current database values
         l_clev_rec := get_rec(p_clev_rec, l_row_notfound);
         IF (l_row_notfound) THEN
            l_return_status := okc_api.g_ret_sts_unexp_error;
         END IF;
         IF (x_clev_rec.id = okc_api.g_miss_num) THEN
            x_clev_rec.id := l_clev_rec.id;
         END IF;
         IF (x_clev_rec.object_version_number = okc_api.g_miss_num) THEN
            x_clev_rec.object_version_number := l_clev_rec.object_version_number;
         END IF;
         IF (x_clev_rec.sfwt_flag = okc_api.g_miss_char) THEN
            x_clev_rec.sfwt_flag := l_clev_rec.sfwt_flag;
         END IF;
         IF (x_clev_rec.chr_id = okc_api.g_miss_num) THEN
            x_clev_rec.chr_id := l_clev_rec.chr_id;
         END IF;
         IF (x_clev_rec.cle_id = okc_api.g_miss_num) THEN
            x_clev_rec.cle_id := l_clev_rec.cle_id;
         END IF;
         IF (x_clev_rec.lse_id = okc_api.g_miss_num) THEN
            x_clev_rec.lse_id := l_clev_rec.lse_id;
         END IF;
         IF (x_clev_rec.line_number = okc_api.g_miss_char) THEN
            x_clev_rec.line_number := l_clev_rec.line_number;
         END IF;
         IF (x_clev_rec.sts_code = okc_api.g_miss_char) THEN
            x_clev_rec.sts_code := l_clev_rec.sts_code;
         END IF;
         IF (x_clev_rec.display_sequence = okc_api.g_miss_num) THEN
            x_clev_rec.display_sequence := l_clev_rec.display_sequence;
         END IF;
         IF (x_clev_rec.trn_code = okc_api.g_miss_char) THEN
            x_clev_rec.trn_code := l_clev_rec.trn_code;
         END IF;
         IF (x_clev_rec.dnz_chr_id = okc_api.g_miss_num) THEN
            x_clev_rec.dnz_chr_id := l_clev_rec.dnz_chr_id;
         END IF;
         IF (x_clev_rec.comments = okc_api.g_miss_char) THEN
            x_clev_rec.comments := l_clev_rec.comments;
         END IF;
         IF (x_clev_rec.item_description = okc_api.g_miss_char) THEN
            x_clev_rec.item_description := l_clev_rec.item_description;
         END IF;
         IF (x_clev_rec.oke_boe_description = okc_api.g_miss_char) THEN
            x_clev_rec.oke_boe_description := l_clev_rec.oke_boe_description;
         END IF;
         IF (x_clev_rec.cognomen = okc_api.g_miss_char) THEN
            x_clev_rec.cognomen := l_clev_rec.cognomen;
         END IF;
         IF (x_clev_rec.hidden_ind = okc_api.g_miss_char) THEN
            x_clev_rec.hidden_ind := l_clev_rec.hidden_ind;
         END IF;
         IF (x_clev_rec.price_unit = okc_api.g_miss_num) THEN
            x_clev_rec.price_unit := l_clev_rec.price_unit;
         END IF;
         IF (x_clev_rec.price_unit_percent = okc_api.g_miss_num) THEN
            x_clev_rec.price_unit_percent := l_clev_rec.price_unit_percent;
         END IF;
         IF (x_clev_rec.price_negotiated = okc_api.g_miss_num) THEN
            x_clev_rec.price_negotiated := l_clev_rec.price_negotiated;
         END IF;
         IF (x_clev_rec.price_negotiated_renewed = okc_api.g_miss_num) THEN
            x_clev_rec.price_negotiated_renewed := l_clev_rec.price_negotiated_renewed;
         END IF;
         IF (x_clev_rec.price_level_ind = okc_api.g_miss_char) THEN
            x_clev_rec.price_level_ind := l_clev_rec.price_level_ind;
         END IF;
         IF (x_clev_rec.invoice_line_level_ind = okc_api.g_miss_char) THEN
            x_clev_rec.invoice_line_level_ind := l_clev_rec.invoice_line_level_ind;
         END IF;
         IF (x_clev_rec.dpas_rating = okc_api.g_miss_char) THEN
            x_clev_rec.dpas_rating := l_clev_rec.dpas_rating;
         END IF;
         IF (x_clev_rec.block23text = okc_api.g_miss_char) THEN
            x_clev_rec.block23text := l_clev_rec.block23text;
         END IF;
         IF (x_clev_rec.exception_yn = okc_api.g_miss_char) THEN
            x_clev_rec.exception_yn := l_clev_rec.exception_yn;
         END IF;
         IF (x_clev_rec.template_used = okc_api.g_miss_char) THEN
            x_clev_rec.template_used := l_clev_rec.template_used;
         END IF;
         IF (x_clev_rec.date_terminated = okc_api.g_miss_date) THEN
            x_clev_rec.date_terminated := l_clev_rec.date_terminated;
         END IF;
         IF (x_clev_rec.NAME = okc_api.g_miss_char) THEN
            x_clev_rec.NAME := l_clev_rec.NAME;
         END IF;
         IF (x_clev_rec.start_date = okc_api.g_miss_date) THEN
            x_clev_rec.start_date := l_clev_rec.start_date;
         END IF;
         IF (x_clev_rec.end_date = okc_api.g_miss_date) THEN
            x_clev_rec.end_date := l_clev_rec.end_date;
         END IF;
         IF (x_clev_rec.date_renewed = okc_api.g_miss_date) THEN
            x_clev_rec.date_renewed := l_clev_rec.date_renewed;
         END IF;
         IF (x_clev_rec.upg_orig_system_ref = okc_api.g_miss_char) THEN
            x_clev_rec.upg_orig_system_ref := l_clev_rec.upg_orig_system_ref;
         END IF;
         IF (x_clev_rec.upg_orig_system_ref_id = okc_api.g_miss_num) THEN
            x_clev_rec.upg_orig_system_ref_id := l_clev_rec.upg_orig_system_ref_id;
         END IF;
         IF (x_clev_rec.orig_system_source_code = okc_api.g_miss_char) THEN
            x_clev_rec.orig_system_source_code := l_clev_rec.orig_system_source_code;
         END IF;
         IF (x_clev_rec.orig_system_id1 = okc_api.g_miss_num) THEN
            x_clev_rec.orig_system_id1 := l_clev_rec.orig_system_id1;
         END IF;
         IF (x_clev_rec.orig_system_reference1 = okc_api.g_miss_char) THEN
            x_clev_rec.orig_system_reference1 := l_clev_rec.orig_system_reference1;
         END IF;
         IF (x_clev_rec.program_application_id = okc_api.g_miss_num) THEN
            x_clev_rec.program_application_id := l_clev_rec.program_application_id;
         END IF;
         IF (x_clev_rec.program_id = okc_api.g_miss_num) THEN
            x_clev_rec.program_id := l_clev_rec.program_id;
         END IF;
         IF (x_clev_rec.program_update_date = okc_api.g_miss_date) THEN
            x_clev_rec.program_update_date := l_clev_rec.program_update_date;
         END IF;
         IF (x_clev_rec.request_id = okc_api.g_miss_num) THEN
            x_clev_rec.request_id := l_clev_rec.request_id;
         END IF;
         IF (x_clev_rec.price_list_id = okc_api.g_miss_num) THEN
            x_clev_rec.price_list_id := l_clev_rec.price_list_id;
         END IF;
         IF (x_clev_rec.pricing_date = okc_api.g_miss_date) THEN
            x_clev_rec.pricing_date := l_clev_rec.pricing_date;
         END IF;
         IF (x_clev_rec.price_list_line_id = okc_api.g_miss_num) THEN
            x_clev_rec.price_list_line_id := l_clev_rec.price_list_line_id;
         END IF;
         IF (x_clev_rec.line_list_price = okc_api.g_miss_num) THEN
            x_clev_rec.line_list_price := l_clev_rec.line_list_price;
         END IF;
         IF (x_clev_rec.item_to_price_yn = okc_api.g_miss_char) THEN
            x_clev_rec.item_to_price_yn := l_clev_rec.item_to_price_yn;
         END IF;
         IF (x_clev_rec.price_basis_yn = okc_api.g_miss_char) THEN
            x_clev_rec.price_basis_yn := l_clev_rec.price_basis_yn;
         END IF;
         IF (x_clev_rec.config_header_id = okc_api.g_miss_num) THEN
            x_clev_rec.config_header_id := l_clev_rec.config_header_id;
         END IF;
         IF (x_clev_rec.config_revision_number = okc_api.g_miss_num) THEN
            x_clev_rec.config_revision_number := l_clev_rec.config_revision_number;
         END IF;
         IF (x_clev_rec.config_complete_yn = okc_api.g_miss_char) THEN
            x_clev_rec.config_complete_yn := l_clev_rec.config_complete_yn;
         END IF;
         IF (x_clev_rec.config_valid_yn = okc_api.g_miss_char) THEN
            x_clev_rec.config_valid_yn := l_clev_rec.config_valid_yn;
         END IF;
         IF (x_clev_rec.config_top_model_line_id = okc_api.g_miss_num) THEN
            x_clev_rec.config_top_model_line_id := l_clev_rec.config_top_model_line_id;
         END IF;
         IF (x_clev_rec.config_item_type = okc_api.g_miss_char) THEN
            x_clev_rec.config_item_type := l_clev_rec.config_item_type;
         END IF;
         ---Bug.No.-1942374
         IF (x_clev_rec.config_item_id = okc_api.g_miss_num) THEN
            x_clev_rec.config_item_id := l_clev_rec.config_item_id;
         END IF;
         ---Bug.No.-1942374
         IF (x_clev_rec.attribute_category = okc_api.g_miss_char) THEN
            x_clev_rec.attribute_category := l_clev_rec.attribute_category;
         END IF;
         IF (x_clev_rec.attribute1 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute1 := l_clev_rec.attribute1;
         END IF;
         IF (x_clev_rec.attribute2 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute2 := l_clev_rec.attribute2;
         END IF;
         IF (x_clev_rec.attribute3 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute3 := l_clev_rec.attribute3;
         END IF;
         IF (x_clev_rec.attribute4 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute4 := l_clev_rec.attribute4;
         END IF;
         IF (x_clev_rec.attribute5 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute5 := l_clev_rec.attribute5;
         END IF;
         IF (x_clev_rec.attribute6 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute6 := l_clev_rec.attribute6;
         END IF;
         IF (x_clev_rec.attribute7 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute7 := l_clev_rec.attribute7;
         END IF;
         IF (x_clev_rec.attribute8 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute8 := l_clev_rec.attribute8;
         END IF;
         IF (x_clev_rec.attribute9 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute9 := l_clev_rec.attribute9;
         END IF;
         IF (x_clev_rec.attribute10 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute10 := l_clev_rec.attribute10;
         END IF;
         IF (x_clev_rec.attribute11 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute11 := l_clev_rec.attribute11;
         END IF;
         IF (x_clev_rec.attribute12 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute12 := l_clev_rec.attribute12;
         END IF;
         IF (x_clev_rec.attribute13 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute13 := l_clev_rec.attribute13;
         END IF;
         IF (x_clev_rec.attribute14 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute14 := l_clev_rec.attribute14;
         END IF;
         IF (x_clev_rec.attribute15 = okc_api.g_miss_char) THEN
            x_clev_rec.attribute15 := l_clev_rec.attribute15;
         END IF;
         IF (x_clev_rec.created_by = okc_api.g_miss_num) THEN
            x_clev_rec.created_by := l_clev_rec.created_by;
         END IF;
         IF (x_clev_rec.creation_date = okc_api.g_miss_date) THEN
            x_clev_rec.creation_date := l_clev_rec.creation_date;
         END IF;
         IF (x_clev_rec.last_updated_by = okc_api.g_miss_num) THEN
            x_clev_rec.last_updated_by := l_clev_rec.last_updated_by;
         END IF;
         IF (x_clev_rec.last_update_date = okc_api.g_miss_date) THEN
            x_clev_rec.last_update_date := l_clev_rec.last_update_date;
         END IF;
         IF (x_clev_rec.price_type = okc_api.g_miss_char) THEN
            x_clev_rec.price_type := l_clev_rec.price_type;
         END IF;
         IF (x_clev_rec.currency_code = okc_api.g_miss_char) THEN
            x_clev_rec.currency_code := l_clev_rec.currency_code;
         END IF;
         IF (x_clev_rec.currency_code_renewed = okc_api.g_miss_char) THEN
            x_clev_rec.currency_code_renewed := l_clev_rec.currency_code_renewed;
         END IF;
         IF (x_clev_rec.last_update_login = okc_api.g_miss_num) THEN
            x_clev_rec.last_update_login := l_clev_rec.last_update_login;
         END IF;
         IF (x_clev_rec.service_item_yn = okc_api.g_miss_char) THEN
            x_clev_rec.service_item_yn := l_clev_rec.service_item_yn;
         END IF;
         --new columns for price hold
         IF (x_clev_rec.ph_pricing_type = okc_api.g_miss_char) THEN
            x_clev_rec.ph_pricing_type := l_clev_rec.ph_pricing_type;
         END IF;
         IF (x_clev_rec.ph_price_break_basis = okc_api.g_miss_char) THEN
            x_clev_rec.ph_price_break_basis := l_clev_rec.ph_price_break_basis;
         END IF;
         IF (x_clev_rec.ph_min_qty = okc_api.g_miss_num) THEN
            x_clev_rec.ph_min_qty := l_clev_rec.ph_min_qty;
         END IF;
         IF (x_clev_rec.ph_min_amt = okc_api.g_miss_num) THEN
            x_clev_rec.ph_min_amt := l_clev_rec.ph_min_amt;
         END IF;
         IF (x_clev_rec.ph_qp_reference_id = okc_api.g_miss_num) THEN
            x_clev_rec.ph_qp_reference_id := l_clev_rec.ph_qp_reference_id;
         END IF;
         IF (x_clev_rec.ph_value = okc_api.g_miss_num) THEN
            x_clev_rec.ph_value := l_clev_rec.ph_value;
         END IF;
         IF (x_clev_rec.ph_enforce_price_list_yn = okc_api.g_miss_char) THEN
            x_clev_rec.ph_enforce_price_list_yn := l_clev_rec.ph_enforce_price_list_yn;
         END IF;
         IF (x_clev_rec.ph_adjustment = okc_api.g_miss_num) THEN
            x_clev_rec.ph_adjustment := l_clev_rec.ph_adjustment;
         END IF;
         IF (x_clev_rec.ph_integrated_with_qp = okc_api.g_miss_char) THEN
            x_clev_rec.ph_integrated_with_qp := l_clev_rec.ph_integrated_with_qp;
         END IF;
         -- new  columns to replace rules
         IF (x_clev_rec.cust_acct_id = okc_api.g_miss_num) THEN
            x_clev_rec.cust_acct_id := l_clev_rec.cust_acct_id;
         END IF;
         IF (x_clev_rec.bill_to_site_use_id = okc_api.g_miss_num) THEN
            x_clev_rec.bill_to_site_use_id := l_clev_rec.bill_to_site_use_id;
         END IF;
         IF (x_clev_rec.inv_rule_id = okc_api.g_miss_num) THEN
            x_clev_rec.inv_rule_id := l_clev_rec.inv_rule_id;
         END IF;
         IF (x_clev_rec.line_renewal_type_code = okc_api.g_miss_char) THEN
            x_clev_rec.line_renewal_type_code := l_clev_rec.line_renewal_type_code;
         END IF;
         IF (x_clev_rec.ship_to_site_use_id = okc_api.g_miss_num) THEN
            x_clev_rec.ship_to_site_use_id := l_clev_rec.ship_to_site_use_id;
         END IF;
         IF (x_clev_rec.payment_term_id = okc_api.g_miss_num) THEN
            x_clev_rec.payment_term_id := l_clev_rec.payment_term_id;
         END IF;
         ---- line Level Cancellation ---
         IF (x_clev_rec.date_cancelled = okc_api.g_miss_date) THEN
            x_clev_rec.date_cancelled := l_clev_rec.date_cancelled;
         END IF;
         /*IF (x_clev_rec.canc_reason_code = OKC_API.G_MISS_CHAR) THEN
           x_clev_rec.canc_reason_code := l_clev_rec.canc_reason_code;
         END IF;*/
         IF (x_clev_rec.term_cancel_source = okc_api.g_miss_char) THEN
            x_clev_rec.term_cancel_source := l_clev_rec.term_cancel_source;
         END IF;
         IF (x_clev_rec.cancelled_amount = okc_api.g_miss_num) THEN
            x_clev_rec.cancelled_amount := l_clev_rec.cancelled_amount;
         END IF;
      
         ---- added by mchoudha 22-JUL ---
         IF (x_clev_rec.payment_instruction_type = okc_api.g_miss_char) THEN
            x_clev_rec.payment_instruction_type := l_clev_rec.payment_instruction_type;
         END IF;
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('19900: Leaving populate_new_record ', 2);
            okc_debug.reset_indentation;
         END IF;
      
         RETURN(l_return_status);
      
      END populate_new_record;
      --------------------------------------
      -- Set_Attributes for:OKC_K_LINES_V --
      --------------------------------------
      FUNCTION set_attributes(p_clev     IN clev_rec_type,
                              x_clev_rec OUT NOCOPY clev_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_clev_rec                       := p_clev_rec;
         x_clev_rec.object_version_number := nvl(x_clev_rec.object_version_number,
                                                 0) + 1;
         /************************ HAND-CODED *********************************/
         x_clev_rec.sfwt_flag              := upper(x_clev_rec.sfwt_flag);
         x_clev_rec.hidden_ind             := upper(x_clev_rec.hidden_ind);
         x_clev_rec.price_level_ind        := upper(x_clev_rec.price_level_ind);
         x_clev_rec.invoice_line_level_ind := upper(x_clev_rec.invoice_line_level_ind);
         x_clev_rec.exception_yn           := upper(x_clev_rec.exception_yn);
         x_clev_rec.item_to_price_yn       := upper(x_clev_rec.item_to_price_yn);
         x_clev_rec.price_basis_yn         := upper(x_clev_rec.price_basis_yn);
         x_clev_rec.config_complete_yn     := upper(x_clev_rec.config_complete_yn);
         x_clev_rec.config_valid_yn        := upper(x_clev_rec.config_valid_yn);
         x_clev_rec.config_item_type       := upper(x_clev_rec.config_item_type);
         /*********************** END HAND-CODED ********************************/
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('20000: Entered update_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                
                                                g_pkg_name,
                                                p_init_msg_list,
                                                l_api_version,
                                                p_api_version,
                                                '_PVT',
                                                x_return_status);
   
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --- Setting item attributes
      l_return_status := set_attributes(p_clev_rec, -- IN
                                        l_clev_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_return_status := populate_new_record(l_clev_rec, l_def_clev_rec);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_def_clev_rec := fill_who_columns(l_def_clev_rec);
   
      IF p_clev_rec.validate_yn = 'Y' THEN
         ---Bug#3150149
         --- Validate all non-missing attributes (Item Level Validation)
         -- No validation if the status changes from ENTERED -> CANCELED
         IF (nvl(p_clev_rec.new_ste_code, 'x') <> 'CANCELLED') THEN
            l_return_status := validate_attributes(l_def_clev_rec);
         END IF;
      END IF; ---Bug#3150149.
   
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      l_return_status := validate_record(l_def_clev_rec);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
   
      --------------------------------------
      -- Move VIEW record to "Child" records
      --------------------------------------
      migrate(l_def_clev_rec, l_okc_k_lines_tl_rec);
      migrate(l_def_clev_rec, l_cle_rec);
      --------------------------------------------
      -- Call the UPDATE_ROW for each child record
      --------------------------------------------
      update_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_okc_k_lines_tl_rec,
                 lx_okc_k_lines_tl_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      migrate(lx_okc_k_lines_tl_rec, l_def_clev_rec);
      update_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 p_restricted_update,
                 l_cle_rec,
                 lx_cle_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      migrate(lx_cle_rec, l_def_clev_rec);
      x_clev_rec := l_def_clev_rec;
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('20100: Exiting update_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('20200: Exiting update_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('20300: Exiting update_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('20400: Exiting update_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END update_row;
   ----------------------------------------
   -- PL/SQL TBL update_row for:CLEV_TBL --
   ----------------------------------------
   PROCEDURE update_row(p_api_version       IN NUMBER,
                        p_init_msg_list     IN VARCHAR2,
                        x_return_status     OUT NOCOPY VARCHAR2,
                        x_msg_count         OUT NOCOPY NUMBER,
                        x_msg_data          OUT NOCOPY VARCHAR2,
                        p_restricted_update IN VARCHAR2,
                        p_clev_tbl          IN clev_tbl_type,
                        x_clev_tbl          OUT NOCOPY clev_tbl_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_tbl_update_row';
      l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      i                NUMBER := 0;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('20500: Entered update_row', 2);
      END IF;
   
      okc_api.init_msg_list(p_init_msg_list);
      -- Make sure PL/SQL table has records in it before passing
      IF (p_clev_tbl.COUNT > 0) THEN
         i := p_clev_tbl.FIRST;
         LOOP
            update_row(p_api_version       => p_api_version,
                       p_init_msg_list     => okc_api.g_false,
                       x_return_status     => x_return_status,
                       x_msg_count         => x_msg_count,
                       x_msg_data          => x_msg_data,
                       p_restricted_update => p_restricted_update,
                       p_clev_rec          => p_clev_tbl(i),
                       x_clev_rec          => x_clev_tbl(i));
         
            -- store the highest degree of error
            IF x_return_status <> okc_api.g_ret_sts_success THEN
               IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                  l_overall_status := x_return_status;
               END IF;
            END IF;
         
            EXIT WHEN(i = p_clev_tbl.LAST);
            i := p_clev_tbl.NEXT(i);
         END LOOP;
         -- return overall status
         x_return_status := l_overall_status;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('20600: Exiting update_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('20700: Exiting update_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('20800: Exiting update_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('20900: Exiting update_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END update_row;

   ---------------------------------------------------------------------------
   -- PROCEDURE delete_row
   ---------------------------------------------------------------------------
   ----------------------------------
   -- delete_row for:OKC_K_LINES_B --
   ----------------------------------
   PROCEDURE delete_row(p_init_msg_list IN VARCHAR2,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_cle_rec       IN cle_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'B_delete_row';
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_cle_rec       cle_rec_type := p_cle_rec;
      l_row_notfound  BOOLEAN := TRUE;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('21000: Entered delete_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      DELETE FROM okc_k_lines_b WHERE id = l_cle_rec.id;
   
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('21100: Leaving delete_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('21200: Exiting delete_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('21300: Exiting delete_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('21400: Exiting delete_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END delete_row;
   -----------------------------------
   -- delete_row for:OKC_K_LINES_TL --
   -----------------------------------
   PROCEDURE delete_row(p_init_msg_list      IN VARCHAR2,
                        x_return_status      OUT NOCOPY VARCHAR2,
                        x_msg_count          OUT NOCOPY NUMBER,
                        x_msg_data           OUT NOCOPY VARCHAR2,
                        p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'TL_delete_row';
      l_return_status      VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type := p_okc_k_lines_tl_rec;
      l_row_notfound       BOOLEAN := TRUE;
      ---------------------------------------
      -- Set_Attributes for:OKC_K_LINES_TL --
      ---------------------------------------
      FUNCTION set_attributes(p_okc_k_lines_tl_rec IN okc_k_lines_tl_rec_type,
                              x_okc_k_lines_tl_rec OUT NOCOPY okc_k_lines_tl_rec_type)
         RETURN VARCHAR2 IS
         l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      BEGIN
      
         x_okc_k_lines_tl_rec          := p_okc_k_lines_tl_rec;
         x_okc_k_lines_tl_rec.LANGUAGE := okc_util.get_userenv_lang;
         RETURN(l_return_status);
      
      END set_attributes;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('21600: Entered delete_row', 2);
      END IF;
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                p_init_msg_list,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      --- Setting item attributes
      l_return_status := set_attributes(p_okc_k_lines_tl_rec, -- IN
                                        l_okc_k_lines_tl_rec); -- OUT
      --- If any errors happen abort API
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      DELETE FROM okc_k_lines_tl WHERE id = l_okc_k_lines_tl_rec.id;
   
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('21700: Exiting delete_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('21800: Exiting delete_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('21900: Exiting delete_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('22000: Exiting delete_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END delete_row;
   ----------------------------------
   -- delete_row for:OKC_K_LINES_V --
   ----------------------------------
   PROCEDURE delete_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_rec      IN clev_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_delete_row';
      l_return_status      VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_clev_rec           clev_rec_type := p_clev_rec;
      l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
      l_cle_rec            cle_rec_type;
      l_olev_rec           okc_oper_inst_pub.olev_rec_type;
      x_olev_rec           okc_oper_inst_pub.olev_rec_type;
      l_opn_code           VARCHAR2(30);
      l_ste_code           VARCHAR2(30);
      l_parent_line_id     NUMBER;
   
      --
      -- Cursor to get operation lines to delete or update
      -- id required to delete or update
      -- object_version_number required in case of update
      -- oie_id to get cop_id in the next cursor to determine
      -- whether the instance is renewal or renew consolidation (RENEWAL/REN_CON)
      --
   
      -- Added for bug # 3909534
      CURSOR ole_csr IS
         SELECT id,
                object_version_number,
                oie_id,
                object_chr_id,
                active_yn,
                object_cle_id
           FROM okc_operation_lines
          WHERE subject_cle_id = p_clev_rec.id;
   
      CURSOR c_parent_line_id(p_line_id NUMBER) IS
         SELECT cle_id
           FROM okc_k_lines_b
          WHERE id = p_line_id AND
                lse_id IN (7, 8, 9, 10, 11, 13, 18, 25, 35);
   
      CURSOR cop_csr(p_oie_id NUMBER) IS
         SELECT opn_code
           FROM okc_class_operations
          WHERE id = (SELECT cop_id
                        FROM okc_operation_instances
                       WHERE id = p_oie_id);
   
      --
      -- A contract line cannot be deleted unless it is in
      -- ENTERED or CANCELLED status
      -- Bug# 1646987
      --
      CURSOR ste_csr IS
         SELECT ste_code
           FROM okc_statuses_b
          WHERE code =
                (SELECT sts_code FROM okc_k_lines_b WHERE id = p_clev_rec.id);
   
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('22100: Entered delete_row', 2);
      END IF;
   
      -- Check whether the line is updateable or not
      OPEN ste_csr;
      FETCH ste_csr
         INTO l_ste_code;
      CLOSE ste_csr;
   
/*      IF (l_ste_code NOT IN ('ENTERED', 'CANCELLED')) THEN
      
         okc_api.set_message(p_app_name => g_app_name,
                             p_msg_name => 'OKC_CANNOT_DELETE_LINE');
      
         -- notify caller of an error
         x_return_status := okc_api.g_ret_sts_error;
      
         RETURN;
      
      END IF;*/
   
      l_return_status := okc_api.start_activity(l_api_name,
                                                g_pkg_name,
                                                p_init_msg_list,
                                                l_api_version,
                                                p_api_version,
                                                '_PVT',
                                                x_return_status);
      IF (l_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (l_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
   
      --------------------------------------
      -- Move VIEW record to "Child" records
      --------------------------------------
      migrate(l_clev_rec, l_okc_k_lines_tl_rec);
      migrate(l_clev_rec, l_cle_rec);
   
      --------------------------------------------
      -- Call the DELETE_ROW for each child record
      --------------------------------------------
      delete_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_okc_k_lines_tl_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      delete_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_cle_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
   
      -- delete all renewal links from operation lines
      -- for the current line as subject line
      --
      -- only one record per line in operation lines
      -- loop used for implicit cursor opening
      --
      FOR ole_rec IN ole_csr LOOP
         --
         -- When a line is deleted, if the line is renewed from a contract
         -- that contract cannot be considered as renewed
         -- so, set the date_renewed of that source contract to null
         --
         IF (ole_rec.active_yn = 'Y') THEN
            --npalepu 08-11-2005 modified for bug # 4691662.
            --Replaced table okc_k_headers_b with headers_All_b table
            /* UPDATE okc_k_headers_b */
            UPDATE okc_k_headers_all_b
            --end npalepu
               SET date_renewed = NULL
             WHERE id = ole_rec.object_chr_id AND
                   date_renewed IS NOT NULL;
         END IF;
      
         l_olev_rec.id                    := ole_rec.id;
         l_olev_rec.object_version_number := ole_rec.object_version_number;
      
         OPEN cop_csr(ole_rec.oie_id);
         FETCH cop_csr
            INTO l_opn_code;
         CLOSE cop_csr;
      
         IF (l_opn_code = 'RENEWAL') THEN
         
            okc_oper_inst_pub.delete_operation_line(p_api_version   => p_api_version,
                                                    p_init_msg_list => p_init_msg_list,
                                                    x_return_status => x_return_status,
                                                    x_msg_count     => x_msg_count,
                                                    x_msg_data      => x_msg_data,
                                                    p_olev_rec      => l_olev_rec);
         
         ELSIF (l_opn_code = 'REN_CON') THEN
         
            -- Bug fix#3909534 starts
         
            l_parent_line_id := NULL;
         
            UPDATE okc_k_lines_b
               SET date_renewed = NULL
             WHERE id = ole_rec.object_cle_id AND
                   date_renewed IS NOT NULL;
         
            -- Update Parent Line (Source Contract Top Line) date_renewed
            OPEN c_parent_line_id(ole_rec.object_cle_id);
            FETCH c_parent_line_id
               INTO l_parent_line_id;
            CLOSE c_parent_line_id;
         
            IF l_parent_line_id IS NOT NULL THEN
               UPDATE okc_k_lines_b
                  SET date_renewed = NULL
                WHERE id = l_parent_line_id AND
                      date_renewed IS NOT NULL;
            END IF;
            --
            -- Bug fix ends
         
            l_olev_rec.subject_cle_id := NULL;
            l_olev_rec.process_flag   := 'A';
            l_olev_rec.active_yn      := 'N';
         
            okc_oper_inst_pub.update_operation_line(p_api_version   => p_api_version,
                                                    p_init_msg_list => p_init_msg_list,
                                                    x_return_status => x_return_status,
                                                    x_msg_count     => x_msg_count,
                                                    x_msg_data      => x_msg_data,
                                                    p_olev_rec      => l_olev_rec,
                                                    x_olev_rec      => x_olev_rec);
         END IF;
      
         IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE okc_api.g_exception_unexpected_error;
         ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
            RAISE okc_api.g_exception_error;
         END IF;
      END LOOP;
   
      okc_api.end_activity(x_msg_count, x_msg_data);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('22200: Exiting delete_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('22300: Exiting delete_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('22400: Exiting delete_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('22500: Exiting delete_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END delete_row;
   ----------------------------------------
   -- PL/SQL TBL delete_row for:CLEV_TBL --
   ----------------------------------------
   PROCEDURE delete_row(p_api_version   IN NUMBER,
                        p_init_msg_list IN VARCHAR2,
                        x_return_status OUT NOCOPY VARCHAR2,
                        x_msg_count     OUT NOCOPY NUMBER,
                        x_msg_data      OUT NOCOPY VARCHAR2,
                        p_clev_tbl      IN clev_tbl_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_tbl_delete_row';
      l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      i                NUMBER := 0;
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('22600: Entered delete_row', 2);
      END IF;
   
      okc_api.init_msg_list(p_init_msg_list);
      -- Make sure PL/SQL table has records in it before passing
      IF (p_clev_tbl.COUNT > 0) THEN
         i := p_clev_tbl.FIRST;
         LOOP
            delete_row(p_api_version   => p_api_version,
                       p_init_msg_list => okc_api.g_false,
                       x_return_status => x_return_status,
                       x_msg_count     => x_msg_count,
                       x_msg_data      => x_msg_data,
                       p_clev_rec      => p_clev_tbl(i));
         
            -- store the highest degree of error
            IF x_return_status <> okc_api.g_ret_sts_success THEN
               IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                  l_overall_status := x_return_status;
               END IF;
            END IF;
         
            EXIT WHEN(i = p_clev_tbl.LAST);
            i := p_clev_tbl.NEXT(i);
         END LOOP;
         -- return overall status
         x_return_status := l_overall_status;
      END IF;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('22700: Exiting delete_row', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('22800: Exiting delete_row:OKC_API.G_EXCEPTION_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('22900: Exiting delete_row:OKC_API.G_EXCEPTION_UNEXPECTED_ERROR Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('23000: Exiting delete_row:OTHERS Exception', 2);
            okc_debug.reset_indentation;
         END IF;
      
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      
   END delete_row;

   --------------------------------------------
   -- force_delete_row for:OKC_K_LINES_V --
   --------------------------------------------
   PROCEDURE force_delete_row(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2,
                              p_clev_rec      IN clev_rec_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_delete_row';
      l_return_status      VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_clev_rec           clev_rec_type := p_clev_rec;
      l_okc_k_lines_tl_rec okc_k_lines_tl_rec_type;
      l_cle_rec            cle_rec_type;
      l_olev_rec           okc_oper_inst_pub.olev_rec_type;
      x_olev_rec           okc_oper_inst_pub.olev_rec_type;
      l_opn_code           VARCHAR2(30);
      l_ste_code           VARCHAR2(30);
   
      --
      -- Cursor to get operation lines to delete or update
      -- id required to delete or update
      -- object_version_number required in case of update
      -- oie_id to get cop_id in the next cursor to determine
      -- whether the instance is renewal or renew consolidation (RENEWAL/REN_CON)
      --
      CURSOR ole_csr IS
         SELECT id, object_version_number, oie_id, object_chr_id, active_yn
           FROM okc_operation_lines
          WHERE subject_cle_id = p_clev_rec.id;
   
      CURSOR cop_csr(p_oie_id NUMBER) IS
         SELECT opn_code
           FROM okc_class_operations
          WHERE id = (SELECT cop_id
                        FROM okc_operation_instances
                       WHERE id = p_oie_id);
   
   BEGIN
   
      --------------------------------------
      -- Move VIEW record to "Child" records
      --------------------------------------
      migrate(l_clev_rec, l_okc_k_lines_tl_rec);
      migrate(l_clev_rec, l_cle_rec);
   
      --------------------------------------------
      -- Call the DELETE_ROW for each child record
      --------------------------------------------
      delete_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_okc_k_lines_tl_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
      delete_row(p_init_msg_list,
                 x_return_status,
                 x_msg_count,
                 x_msg_data,
                 l_cle_rec);
      IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
         RAISE okc_api.g_exception_unexpected_error;
      ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
         RAISE okc_api.g_exception_error;
      END IF;
   
      -- delete all renewal links from operation lines
      -- for the current line as subject line
      --
      -- only one record per line in operation lines
      -- loop used for implicit cursor opening
      --
      FOR ole_rec IN ole_csr LOOP
         --
         -- When a line is deleted, if the line is renewed from a contract
         -- that contract cannot be considered as renewed
         -- so, set the date_renewed of that source contract to null
         --
         IF (ole_rec.active_yn = 'Y') THEN
            --npalepu 08-11-2005 modified for bug # 4691662.
            --Replaced table okc_k_headers_b with headers_All_b table
            /* UPDATE okc_k_headers_b */
            UPDATE okc_k_headers_all_b
            --end npalepu
               SET date_renewed = NULL
             WHERE id = ole_rec.object_chr_id AND
                   date_renewed IS NOT NULL;
         END IF;
      
         l_olev_rec.id                    := ole_rec.id;
         l_olev_rec.object_version_number := ole_rec.object_version_number;
      
         OPEN cop_csr(ole_rec.oie_id);
         FETCH cop_csr
            INTO l_opn_code;
         CLOSE cop_csr;
      
         IF (l_opn_code = 'RENEWAL') THEN
         
            okc_oper_inst_pub.delete_operation_line(p_api_version   => p_api_version,
                                                    p_init_msg_list => p_init_msg_list,
                                                    x_return_status => x_return_status,
                                                    x_msg_count     => x_msg_count,
                                                    x_msg_data      => x_msg_data,
                                                    p_olev_rec      => l_olev_rec);
         
         ELSIF (l_opn_code = 'REN_CON') THEN
         
            l_olev_rec.subject_cle_id := NULL;
            l_olev_rec.process_flag   := 'A';
            l_olev_rec.active_yn      := 'N';
         
            okc_oper_inst_pub.update_operation_line(p_api_version   => p_api_version,
                                                    p_init_msg_list => p_init_msg_list,
                                                    x_return_status => x_return_status,
                                                    x_msg_count     => x_msg_count,
                                                    x_msg_data      => x_msg_data,
                                                    p_olev_rec      => l_olev_rec,
                                                    x_olev_rec      => x_olev_rec);
         END IF;
      
         IF (x_return_status = okc_api.g_ret_sts_unexp_error) THEN
            RAISE okc_api.g_exception_unexpected_error;
         ELSIF (x_return_status = okc_api.g_ret_sts_error) THEN
            RAISE okc_api.g_exception_error;
         END IF;
      END LOOP;
   
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
   END force_delete_row;

   ---------------------------------------------------
   -- PL/SQL TBL force_delete_row for:CLEV_TBL --
   ---------------------------------------------------
   PROCEDURE force_delete_row(p_api_version   IN NUMBER,
                              p_init_msg_list IN VARCHAR2,
                              x_return_status OUT NOCOPY VARCHAR2,
                              x_msg_count     OUT NOCOPY NUMBER,
                              x_msg_data      OUT NOCOPY VARCHAR2,
                              p_clev_tbl      IN clev_tbl_type) IS
   
      l_api_version CONSTANT NUMBER := 1;
      l_api_name    CONSTANT VARCHAR2(30) := 'V_tbl_delete_row';
      l_return_status  VARCHAR2(1) := okc_api.g_ret_sts_success;
      l_overall_status VARCHAR2(1) := okc_api.g_ret_sts_success;
      i                NUMBER := 0;
   BEGIN
      okc_api.init_msg_list(p_init_msg_list);
      -- Make sure PL/SQL table has records in it before passing
      IF (p_clev_tbl.COUNT > 0) THEN
         i := p_clev_tbl.FIRST;
         LOOP
            force_delete_row(p_api_version   => p_api_version,
                             p_init_msg_list => okc_api.g_false,
                             x_return_status => x_return_status,
                             x_msg_count     => x_msg_count,
                             x_msg_data      => x_msg_data,
                             p_clev_rec      => p_clev_tbl(i));
         
            -- store the highest degree of error
            IF x_return_status <> okc_api.g_ret_sts_success THEN
               IF l_overall_status <> okc_api.g_ret_sts_unexp_error THEN
                  l_overall_status := x_return_status;
               END IF;
            END IF;
         
            EXIT WHEN(i = p_clev_tbl.LAST);
            i := p_clev_tbl.NEXT(i);
         END LOOP;
         -- return overall status
         x_return_status := l_overall_status;
      END IF;
   EXCEPTION
      WHEN okc_api.g_exception_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN okc_api.g_exception_unexpected_error THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OKC_API.G_RET_STS_UNEXP_ERROR',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
      WHEN OTHERS THEN
         x_return_status := okc_api.handle_exceptions(l_api_name,
                                                      g_pkg_name,
                                                      'OTHERS',
                                                      x_msg_count,
                                                      x_msg_data,
                                                      '_PVT');
   END force_delete_row;

   ---------------------------------------------------------------
   -- Procedure for mass insert in OKC_K_LINES _B and TL tables
   ---------------------------------------------------------------
   PROCEDURE insert_row_upg(x_return_status OUT NOCOPY VARCHAR2,
                            p_clev_tbl      clev_tbl_type) IS
      l_tabsize     NUMBER := p_clev_tbl.COUNT;
      l_source_lang VARCHAR2(12) := okc_util.get_userenv_lang;
   
      in_id                       okc_datatypes.numbertabtyp;
      in_object_version_number    okc_datatypes.numbertabtyp;
      in_sfwt_flag                okc_datatypes.var3tabtyp;
      in_chr_id                   okc_datatypes.numbertabtyp;
      in_cle_id                   okc_datatypes.numbertabtyp;
      in_lse_id                   okc_datatypes.numbertabtyp;
      in_line_number              okc_datatypes.var150tabtyp;
      in_sts_code                 okc_datatypes.var30tabtyp;
      in_display_sequence         okc_datatypes.numbertabtyp;
      in_trn_code                 okc_datatypes.var30tabtyp;
      in_dnz_chr_id               okc_datatypes.numbertabtyp;
      in_comments                 okc_datatypes.var1995tabtyp;
      in_item_description         okc_datatypes.var1995tabtyp;
      in_oke_boe_description      okc_datatypes.var1995tabtyp;
      in_cognomen                 okc_datatypes.var300tabtyp;
      in_hidden_ind               okc_datatypes.var3tabtyp;
      in_price_unit               okc_datatypes.numbertabtyp;
      in_price_unit_percent       okc_datatypes.numbertabtyp;
      in_price_negotiated         okc_datatypes.numbertabtyp;
      in_price_negotiated_renewed okc_datatypes.numbertabtyp;
      in_price_level_ind          okc_datatypes.var3tabtyp;
      in_invoice_line_level_ind   okc_datatypes.var3tabtyp;
      in_dpas_rating              okc_datatypes.var24tabtyp;
      in_block23text              okc_datatypes.var1995tabtyp;
      in_exception_yn             okc_datatypes.var3tabtyp;
      in_template_used            okc_datatypes.var150tabtyp;
      in_date_terminated          okc_datatypes.datetabtyp;
      in_name                     okc_datatypes.var150tabtyp;
      in_start_date               okc_datatypes.datetabtyp;
      in_end_date                 okc_datatypes.datetabtyp;
      in_date_renewed             okc_datatypes.datetabtyp;
      in_upg_orig_system_ref      okc_datatypes.var75tabtyp;
      in_upg_orig_system_ref_id   okc_datatypes.numbertabtyp;
      in_orig_system_source_code  okc_datatypes.var30tabtyp;
      in_orig_system_id1          okc_datatypes.numbertabtyp;
      in_orig_system_reference1   okc_datatypes.var30tabtyp;
      in_request_id               okc_datatypes.numbertabtyp;
      in_program_application_id   okc_datatypes.numbertabtyp;
      in_program_id               okc_datatypes.numbertabtyp;
      in_program_update_date      okc_datatypes.datetabtyp;
      in_price_list_id            okc_datatypes.numbertabtyp;
      in_pricing_date             okc_datatypes.datetabtyp;
      in_price_list_line_id       okc_datatypes.numbertabtyp;
      in_line_list_price          okc_datatypes.numbertabtyp;
      in_item_to_price_yn         okc_datatypes.var3tabtyp;
      in_price_basis_yn           okc_datatypes.var3tabtyp;
      in_config_header_id         okc_datatypes.numbertabtyp;
      in_config_revision_number   okc_datatypes.numbertabtyp;
      in_config_complete_yn       okc_datatypes.var3tabtyp;
      in_config_valid_yn          okc_datatypes.var3tabtyp;
      in_config_top_model_line_id okc_datatypes.numbertabtyp;
      in_config_item_type         okc_datatypes.var30tabtyp;
      ---Bug.No.-1942374
      in_config_item_id okc_datatypes.numbertabtyp;
      ---Bug.No.-1942374
      in_attribute_category    okc_datatypes.var90tabtyp;
      in_attribute1            okc_datatypes.var450tabtyp;
      in_attribute2            okc_datatypes.var450tabtyp;
      in_attribute3            okc_datatypes.var450tabtyp;
      in_attribute4            okc_datatypes.var450tabtyp;
      in_attribute5            okc_datatypes.var450tabtyp;
      in_attribute6            okc_datatypes.var450tabtyp;
      in_attribute7            okc_datatypes.var450tabtyp;
      in_attribute8            okc_datatypes.var450tabtyp;
      in_attribute9            okc_datatypes.var450tabtyp;
      in_attribute10           okc_datatypes.var450tabtyp;
      in_attribute11           okc_datatypes.var450tabtyp;
      in_attribute12           okc_datatypes.var450tabtyp;
      in_attribute13           okc_datatypes.var450tabtyp;
      in_attribute14           okc_datatypes.var450tabtyp;
      in_attribute15           okc_datatypes.var450tabtyp;
      in_created_by            okc_datatypes.numbertabtyp;
      in_creation_date         okc_datatypes.datetabtyp;
      in_last_updated_by       okc_datatypes.numbertabtyp;
      in_last_update_date      okc_datatypes.datetabtyp;
      in_last_update_login     okc_datatypes.numbertabtyp;
      in_price_type            okc_datatypes.var30tabtyp;
      in_currency_code         okc_datatypes.var15tabtyp;
      in_currency_code_renewed okc_datatypes.var15tabtyp;
      i                        NUMBER := p_clev_tbl.FIRST;
      j                        NUMBER := 0;
      in_service_item_yn       okc_datatypes.var3tabtyp;
      --new columns for price hold
      in_ph_pricing_type          okc_datatypes.var30tabtyp;
      in_ph_price_break_basis     okc_datatypes.var30tabtyp;
      in_ph_min_qty               okc_datatypes.numbertabtyp;
      in_ph_min_amt               okc_datatypes.numbertabtyp;
      in_ph_qp_reference_id       okc_datatypes.numbertabtyp;
      in_ph_value                 okc_datatypes.numbertabtyp;
      in_ph_enforce_price_list_yn okc_datatypes.var3tabtyp;
      in_ph_adjustment            okc_datatypes.numbertabtyp;
      in_ph_integrated_with_qp    okc_datatypes.var3tabtyp;
      --new columns to replace rules
      in_cust_acct_id             okc_datatypes.number15tabtyp;
      in_bill_to_site_use_id      okc_datatypes.number15tabtyp;
      in_inv_rule_id              okc_datatypes.number15tabtyp;
      in_line_renewal_type_code   okc_datatypes.var30tabtyp;
      in_ship_to_site_use_id      okc_datatypes.number15tabtyp;
      in_payment_term_id          okc_datatypes.number15tabtyp;
      in_payment_instruction_type okc_datatypes.var3tabtyp; --added by mchoudha 22-JUL
   
      /*** R12 Data Model Changes  27072005 ***/
      in_annualized_factor okc_datatypes.numbertabtyp;
      -- Line level Cancellation --
      in_date_cancelled okc_datatypes.datetabtyp;
      -- in_canc_reason_code      OKC_DATATYPES.Var30TabTyp;
      in_term_cancel_source okc_datatypes.var30tabtyp;
      in_cancelled_amount   okc_datatypes.numbertabtyp;
   
      /*** R12 Data Model Changes  27072005 ***/
   
   BEGIN
      -- Initializing return status
      x_return_status := okc_api.g_ret_sts_success;
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('23100: Entered INSERT_ROW_UPG', 2);
      END IF;
   
      -- pkoganti   08/26/2000
      -- replace for loop with while loop to handle
      -- gaps in pl/sql table indexes.
      -- Example:
      --   consider a pl/sql table(A) with the following elements
      --   A(1) = 10
      --   A(2) = 20
      --   A(6) = 30
      --   A(7) = 40
      --
      -- The for loop was erroring for indexes 3,4,5, the while loop
      -- along with the NEXT operator would handle the missing indexes
      -- with out causing the API to fail.
      --
   
      WHILE i IS NOT NULL LOOP
         j := j + 1;
      
         in_id(j) := p_clev_tbl(i).id;
         in_object_version_number(j) := p_clev_tbl(i).object_version_number;
         in_sfwt_flag(j) := p_clev_tbl(i).sfwt_flag;
         in_chr_id(j) := p_clev_tbl(i).chr_id;
         in_cle_id(j) := p_clev_tbl(i).cle_id;
         in_lse_id(j) := p_clev_tbl(i).lse_id;
         in_line_number(j) := p_clev_tbl(i).line_number;
         in_sts_code(j) := p_clev_tbl(i).sts_code;
         in_display_sequence(j) := p_clev_tbl(i).display_sequence;
         in_trn_code(j) := p_clev_tbl(i).trn_code;
         in_dnz_chr_id(j) := p_clev_tbl(i).dnz_chr_id;
         in_comments(j) := p_clev_tbl(i).comments;
         in_item_description(j) := p_clev_tbl(i).item_description;
         in_oke_boe_description(j) := p_clev_tbl(i).oke_boe_description;
         in_cognomen(j) := p_clev_tbl(i).cognomen;
         in_hidden_ind(j) := p_clev_tbl(i).hidden_ind;
         in_price_unit(j) := p_clev_tbl(i).price_unit;
         in_price_unit_percent(j) := p_clev_tbl(i).price_unit_percent;
         in_price_negotiated(j) := p_clev_tbl(i).price_negotiated;
         in_price_negotiated_renewed(j) := p_clev_tbl(i)
                                          .price_negotiated_renewed;
         in_price_level_ind(j) := p_clev_tbl(i).price_level_ind;
         in_invoice_line_level_ind(j) := p_clev_tbl(i)
                                        .invoice_line_level_ind;
         in_dpas_rating(j) := p_clev_tbl(i).dpas_rating;
         in_block23text(j) := p_clev_tbl(i).block23text;
         in_exception_yn(j) := p_clev_tbl(i).exception_yn;
         in_template_used(j) := p_clev_tbl(i).template_used;
         in_date_terminated(j) := p_clev_tbl(i).date_terminated;
         in_name(j) := p_clev_tbl(i).NAME;
         in_start_date(j) := p_clev_tbl(i).start_date;
         in_end_date(j) := p_clev_tbl(i).end_date;
         in_date_renewed(j) := p_clev_tbl(i).date_renewed;
         in_upg_orig_system_ref(j) := p_clev_tbl(i).upg_orig_system_ref;
         in_upg_orig_system_ref_id(j) := p_clev_tbl(i)
                                        .upg_orig_system_ref_id;
         in_orig_system_source_code(j) := p_clev_tbl(i)
                                         .orig_system_source_code;
         in_orig_system_id1(j) := p_clev_tbl(i).orig_system_id1;
         in_orig_system_reference1(j) := p_clev_tbl(i)
                                        .orig_system_reference1;
         in_request_id(j) := p_clev_tbl(i).request_id;
         in_program_application_id(j) := p_clev_tbl(i)
                                        .program_application_id;
         in_program_id(j) := p_clev_tbl(i).program_id;
         in_program_update_date(j) := p_clev_tbl(i).program_update_date;
         in_price_list_id(j) := p_clev_tbl(i).price_list_id;
         in_pricing_date(j) := p_clev_tbl(i).pricing_date;
         in_price_list_line_id(j) := p_clev_tbl(i).price_list_line_id;
         in_line_list_price(j) := p_clev_tbl(i).line_list_price;
         in_item_to_price_yn(j) := p_clev_tbl(i).item_to_price_yn;
         in_price_basis_yn(j) := p_clev_tbl(i).price_basis_yn;
         in_config_header_id(j) := p_clev_tbl(i).config_header_id;
         in_config_revision_number(j) := p_clev_tbl(i)
                                        .config_revision_number;
         in_config_complete_yn(j) := p_clev_tbl(i).config_complete_yn;
         in_config_valid_yn(j) := p_clev_tbl(i).config_valid_yn;
         in_config_top_model_line_id(j) := p_clev_tbl(i)
                                          .config_top_model_line_id;
         in_config_item_type(j) := p_clev_tbl(i).config_item_type;
         ---Bug.No.-1942374
         in_config_item_id(j) := p_clev_tbl(i).config_item_id;
         ---Bug.No.-1942374
         in_attribute_category(j) := p_clev_tbl(i).attribute_category;
         in_attribute1(j) := p_clev_tbl(i).attribute1;
         in_attribute2(j) := p_clev_tbl(i).attribute2;
         in_attribute3(j) := p_clev_tbl(i).attribute3;
         in_attribute4(j) := p_clev_tbl(i).attribute4;
         in_attribute5(j) := p_clev_tbl(i).attribute5;
         in_attribute6(j) := p_clev_tbl(i).attribute6;
         in_attribute7(j) := p_clev_tbl(i).attribute7;
         in_attribute8(j) := p_clev_tbl(i).attribute8;
         in_attribute9(j) := p_clev_tbl(i).attribute9;
         in_attribute10(j) := p_clev_tbl(i).attribute10;
         in_attribute11(j) := p_clev_tbl(i).attribute11;
         in_attribute12(j) := p_clev_tbl(i).attribute12;
         in_attribute13(j) := p_clev_tbl(i).attribute13;
         in_attribute14(j) := p_clev_tbl(i).attribute14;
         in_attribute15(j) := p_clev_tbl(i).attribute15;
         in_created_by(j) := p_clev_tbl(i).created_by;
         in_creation_date(j) := p_clev_tbl(i).creation_date;
         in_last_updated_by(j) := p_clev_tbl(i).last_updated_by;
         in_last_update_date(j) := p_clev_tbl(i).last_update_date;
         in_last_update_login(j) := p_clev_tbl(i).last_update_login;
         in_price_type(j) := p_clev_tbl(i).price_type;
         in_currency_code(j) := p_clev_tbl(i).currency_code;
         in_currency_code_renewed(j) := p_clev_tbl(i).currency_code_renewed;
         in_service_item_yn(j) := p_clev_tbl(i).service_item_yn;
         --new columns for price hold
         in_ph_pricing_type(j) := p_clev_tbl(i).ph_pricing_type;
         in_ph_price_break_basis(j) := p_clev_tbl(i).ph_price_break_basis;
         in_ph_min_qty(j) := p_clev_tbl(i).ph_min_qty;
         in_ph_min_amt(j) := p_clev_tbl(i).ph_min_amt;
         in_ph_qp_reference_id(j) := p_clev_tbl(i).ph_qp_reference_id;
         in_ph_value(j) := p_clev_tbl(i).ph_value;
         in_ph_enforce_price_list_yn(j) := p_clev_tbl(i)
                                          .ph_enforce_price_list_yn;
         in_ph_adjustment(j) := p_clev_tbl(i).ph_adjustment;
         in_ph_integrated_with_qp(j) := p_clev_tbl(i).ph_integrated_with_qp;
         -- new columns to replave rules
         in_cust_acct_id(j) := p_clev_tbl(i).cust_acct_id;
         in_bill_to_site_use_id(j) := p_clev_tbl(i).bill_to_site_use_id;
         in_inv_rule_id(j) := p_clev_tbl(i).inv_rule_id;
         in_line_renewal_type_code(j) := p_clev_tbl(i)
                                        .line_renewal_type_code;
         in_ship_to_site_use_id(j) := p_clev_tbl(i).ship_to_site_use_id;
         in_payment_term_id(j) := p_clev_tbl(i).payment_term_id;
         in_payment_instruction_type(j) := p_clev_tbl(i)
                                          .payment_instruction_type; --added by mchoudha 22-JUL
         /*** R12 Data Model Changes  27072005 ***/
         in_annualized_factor(j) := p_clev_tbl(i).annualized_factor;
         -- Line level Cancellation --
         in_date_cancelled(j) := p_clev_tbl(i).date_cancelled;
         --in_canc_reason_code      (j) := p_clev_tbl(i).canc_reason_code;
         in_term_cancel_source(j) := p_clev_tbl(i).term_cancel_source;
         in_cancelled_amount(j) := p_clev_tbl(i).cancelled_amount;
      
         /*** R12 Data Model Changes  27072005 ***/
         i := p_clev_tbl.NEXT(i);
      END LOOP;
   
      FORALL i IN 1 .. l_tabsize
         INSERT INTO okc_k_lines_b
            (id,
             line_number,
             chr_id,
             cle_id,
             dnz_chr_id,
             display_sequence,
             sts_code,
             trn_code,
             lse_id,
             exception_yn,
             object_version_number,
             created_by,
             creation_date,
             last_updated_by,
             last_update_date,
             hidden_ind,
             price_negotiated,
             price_level_ind,
             price_unit,
             price_unit_percent,
             invoice_line_level_ind,
             dpas_rating,
             template_used,
             price_type,
             currency_code,
             last_update_login,
             date_terminated,
             start_date,
             end_date,
             date_renewed,
             upg_orig_system_ref,
             upg_orig_system_ref_id,
             orig_system_source_code,
             orig_system_id1,
             orig_system_reference1,
             request_id,
             program_application_id,
             program_id,
             program_update_date,
             price_list_id,
             pricing_date,
             price_list_line_id,
             line_list_price,
             item_to_price_yn,
             price_basis_yn,
             config_header_id,
             config_revision_number,
             config_complete_yn,
             config_valid_yn,
             config_top_model_line_id,
             config_item_type,
             ---Bug.No.-1942374
             config_item_id,
             ---Bug.No.-1942374
             attribute_category,
             attribute1,
             attribute2,
             attribute3,
             attribute4,
             attribute5,
             attribute6,
             attribute7,
             attribute8,
             attribute9,
             attribute10,
             attribute11,
             attribute12,
             attribute13,
             attribute14,
             attribute15,
             currency_code_renewed,
             price_negotiated_renewed,
             service_item_yn,
             --new columns for price hold
             ph_pricing_type,
             ph_price_break_basis,
             ph_min_qty,
             ph_min_amt,
             ph_qp_reference_id,
             ph_value,
             ph_enforce_price_list_yn,
             ph_adjustment,
             ph_integrated_with_qp,
             -- new columns to replace rules
             cust_acct_id,
             bill_to_site_use_id,
             inv_rule_id,
             line_renewal_type_code,
             ship_to_site_use_id,
             payment_term_id,
             payment_instruction_type, --added by mchoudha 22-JUL
             /*** R12 data model Changes 27072005 to be checked Start***/
             annualized_factor,
             -- Line level Cancellation --
             date_cancelled,
             --canc_reason_code     ,
             term_cancel_source,
             cancelled_amount
             /*** R12 data model Changes 27072005 to be checked End***/)
         VALUES
            (in_id(i),
             in_line_number(i),
             in_chr_id(i),
             in_cle_id(i),
             in_dnz_chr_id(i),
             in_display_sequence(i),
             in_sts_code(i),
             in_trn_code(i),
             in_lse_id(i),
             in_exception_yn(i),
             in_object_version_number(i),
             in_created_by(i),
             in_creation_date(i),
             in_last_updated_by(i),
             in_last_update_date(i),
             in_hidden_ind(i),
             in_price_negotiated(i),
             in_price_level_ind(i),
             in_price_unit(i),
             in_price_unit_percent(i),
             in_invoice_line_level_ind(i),
             in_dpas_rating(i),
             in_template_used(i),
             in_price_type(i),
             in_currency_code(i),
             in_last_update_login(i),
             in_date_terminated(i),
             in_start_date(i),
             in_end_date(i),
             in_date_renewed(i),
             in_upg_orig_system_ref(i),
             in_upg_orig_system_ref_id(i),
             in_orig_system_source_code(i),
             in_orig_system_id1(i),
             in_orig_system_reference1(i),
             in_request_id(i),
             in_program_application_id(i),
             in_program_id(i),
             in_program_update_date(i),
             in_price_list_id(i),
             in_pricing_date(i),
             in_price_list_line_id(i),
             in_line_list_price(i),
             in_item_to_price_yn(i),
             in_price_basis_yn(i),
             in_config_header_id(i),
             in_config_revision_number(i),
             in_config_complete_yn(i),
             in_config_valid_yn(i),
             in_config_top_model_line_id(i),
             in_config_item_type(i),
             ---Bug.No.-1942374
             in_config_item_id(i),
             ---Bug.No.-1942374
             in_attribute_category(i),
             in_attribute1(i),
             in_attribute2(i),
             in_attribute3(i),
             in_attribute4(i),
             in_attribute5(i),
             in_attribute6(i),
             in_attribute7(i),
             in_attribute8(i),
             in_attribute9(i),
             in_attribute10(i),
             in_attribute11(i),
             in_attribute12(i),
             in_attribute13(i),
             in_attribute14(i),
             in_attribute15(i),
             in_currency_code_renewed(i),
             in_price_negotiated_renewed(i),
             in_service_item_yn(i),
             --new columns for price hold
             
             in_ph_pricing_type(i),
             in_ph_price_break_basis(i),
             in_ph_min_qty(i),
             in_ph_min_amt(i),
             in_ph_qp_reference_id(i),
             in_ph_value(i),
             in_ph_enforce_price_list_yn(i),
             in_ph_adjustment(i),
             in_ph_integrated_with_qp(i),
             
             --new columns to replace rules
             in_cust_acct_id(i),
             in_bill_to_site_use_id(i),
             in_inv_rule_id(i),
             in_line_renewal_type_code(i),
             in_ship_to_site_use_id(i),
             in_payment_term_id(i),
             in_payment_instruction_type(i), --added by mchoudha 22-JUL
             /*** R12 data model Changes 27072005 to be checked Start***/
             in_annualized_factor(i),
             -- Line level Cancellation --
             in_date_cancelled(i),
             --in_canc_reason_code(i)     ,
             in_term_cancel_source(i),
             in_cancelled_amount(i)
             /*** R12 data model Changes 27072005 to be checked End***/);
   
      FOR lang_i IN okc_util.g_language_code.FIRST .. okc_util.g_language_code.LAST LOOP
         FORALL i IN 1 .. l_tabsize
            INSERT INTO okc_k_lines_tl
               (id,
                LANGUAGE,
                source_lang,
                sfwt_flag,
                NAME,
                comments,
                item_description,
                oke_boe_description,
                cognomen,
                block23text,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                last_update_login)
            VALUES
               (in_id(i),
                okc_util.g_language_code(lang_i),
                l_source_lang,
                in_sfwt_flag(i),
                in_name(i),
                in_comments(i),
                in_item_description(i),
                in_oke_boe_description(i),
                in_cognomen(i),
                in_block23text(i),
                in_created_by(i),
                in_creation_date(i),
                in_last_updated_by(i),
                in_last_update_date(i),
                in_last_update_login(i));
      END LOOP;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('23200: Leaving INSERT_ROW_UPG', 2);
         okc_debug.reset_indentation;
      END IF;
   
   EXCEPTION
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('23300: Exiting INSERT_ROW_UPG:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => g_app_name,
                             p_msg_name     => g_unexpected_error,
                             p_token1       => g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => g_sqlerrm_token,
                             p_token2_value => SQLERRM);
         -- notify caller of an error as UNEXPETED error
         x_return_status := okc_api.g_ret_sts_unexp_error;
      
      --RAISE;
   END insert_row_upg;

   --This function is called from versioning API OKC_VERSION_PVT
   --Old Location: OKCRVERB.pls
   --New Location: Base Table API

   FUNCTION create_version(p_chr_id IN NUMBER, p_major_version IN NUMBER)
      RETURN VARCHAR2 IS
   
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
   
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('23400: Entered create_version', 2);
      END IF;
   
      INSERT INTO okc_k_lines_bh
         (major_version,
          id,
          line_number,
          chr_id,
          cle_id,
          dnz_chr_id,
          display_sequence,
          sts_code,
          trn_code,
          lse_id,
          exception_yn,
          object_version_number,
          created_by,
          creation_date,
          last_updated_by,
          last_update_date,
          hidden_ind,
          price_negotiated,
          price_level_ind,
          price_unit,
          price_unit_percent,
          invoice_line_level_ind,
          dpas_rating,
          template_used,
          price_type,
          --uom_code,
          currency_code,
          last_update_login,
          date_terminated,
          start_date,
          end_date,
          date_renewed,
          orig_system_source_code,
          orig_system_id1,
          orig_system_reference1,
          upg_orig_system_ref,
          upg_orig_system_ref_id,
          request_id,
          program_application_id,
          program_id,
          program_update_date,
          price_list_id,
          pricing_date,
          price_list_line_id,
          line_list_price,
          item_to_price_yn,
          price_basis_yn,
          config_header_id,
          config_revision_number,
          config_complete_yn,
          config_valid_yn,
          config_top_model_line_id,
          config_item_type,
          ---Bug.No.-1942374
          config_item_id,
          ---Bug.No.-1942374
          attribute_category,
          attribute1,
          attribute2,
          attribute3,
          attribute4,
          attribute5,
          attribute6,
          attribute7,
          attribute8,
          attribute9,
          attribute10,
          attribute11,
          attribute12,
          attribute13,
          attribute14,
          attribute15,
          currency_code_renewed,
          price_negotiated_renewed,
          service_item_yn,
          --new columns for price hold
          ph_pricing_type,
          ph_price_break_basis,
          ph_min_qty,
          ph_min_amt,
          ph_qp_reference_id,
          ph_value,
          ph_enforce_price_list_yn,
          ph_adjustment,
          ph_integrated_with_qp,
          -- new columns to replace rules
          cust_acct_id,
          bill_to_site_use_id,
          inv_rule_id,
          line_renewal_type_code,
          ship_to_site_use_id,
          payment_term_id,
          date_cancelled, -- added as part of LLC
          --canc_reason_code,
          term_cancel_source,
          cancelled_amount,
          payment_instruction_type, --added by mchoudha 22-JUL
          annualized_factor --Added by npalepu 26-JUL
          )
         SELECT p_major_version,
                id,
                line_number,
                chr_id,
                cle_id,
                dnz_chr_id,
                display_sequence,
                sts_code,
                trn_code,
                lse_id,
                exception_yn,
                object_version_number,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                hidden_ind,
                price_negotiated,
                price_level_ind,
                price_unit,
                price_unit_percent,
                invoice_line_level_ind,
                dpas_rating,
                template_used,
                price_type,
                --uom_code,
                currency_code,
                last_update_login,
                date_terminated,
                start_date,
                end_date,
                date_renewed,
                orig_system_source_code,
                orig_system_id1,
                orig_system_reference1,
                upg_orig_system_ref,
                upg_orig_system_ref_id,
                request_id,
                program_application_id,
                program_id,
                program_update_date,
                price_list_id,
                pricing_date,
                price_list_line_id,
                line_list_price,
                item_to_price_yn,
                price_basis_yn,
                config_header_id,
                config_revision_number,
                config_complete_yn,
                config_valid_yn,
                config_top_model_line_id,
                config_item_type,
                ---Bug.No.-1942374
                config_item_id,
                ---Bug.No.-1942374
                attribute_category,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                attribute6,
                attribute7,
                attribute8,
                attribute9,
                attribute10,
                attribute11,
                attribute12,
                attribute13,
                attribute14,
                attribute15,
                currency_code_renewed,
                price_negotiated_renewed,
                service_item_yn,
                --new columns for price hold
                ph_pricing_type,
                ph_price_break_basis,
                ph_min_qty,
                ph_min_amt,
                ph_qp_reference_id,
                ph_value,
                ph_enforce_price_list_yn,
                ph_adjustment,
                ph_integrated_with_qp,
                --new columns to replace rules
                cust_acct_id,
                bill_to_site_use_id,
                inv_rule_id,
                line_renewal_type_code,
                ship_to_site_use_id,
                payment_term_id,
                date_cancelled, -- Added as part of LLC
                --canc_reason_code,
                term_cancel_source,
                cancelled_amount,
                payment_instruction_type, --Added by mchoudha 22-JUL
                annualized_factor --Added by npalepu 26-JUL
           FROM okc_k_lines_b
          WHERE dnz_chr_id = p_chr_id;
   
      ----------------------------------
      -- Version TL Table
      ----------------------------------
   
      INSERT INTO okc_k_lines_tlh
         (major_version,
          id,
          LANGUAGE,
          source_lang,
          sfwt_flag,
          NAME,
          comments,
          item_description,
          oke_boe_description,
          cognomen,
          block23text,
          created_by,
          creation_date,
          last_updated_by,
          last_update_date,
          last_update_login)
         SELECT p_major_version,
                id,
                LANGUAGE,
                source_lang,
                sfwt_flag,
                NAME,
                comments,
                item_description,
                oke_boe_description,
                cognomen,
                block23text,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                last_update_login
           FROM okc_k_lines_tl
          WHERE id IN
                (SELECT id FROM okc_k_lines_b WHERE dnz_chr_id = p_chr_id);
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('23500: Exiting create_version', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN l_return_status;
   
   EXCEPTION
      -- other appropriate handlers
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('23600: Exiting create_version:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => okc_version_pvt.g_app_name,
                             p_msg_name     => okc_version_pvt.g_unexpected_error,
                             p_token1       => okc_version_pvt.g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => okc_version_pvt.g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         -- notify  UNEXPECTED error
         l_return_status := okc_api.g_ret_sts_unexp_error;
         RETURN l_return_status;
      
   END create_version;

   --This Function is called from Versioning API OKC_VERSION_PVT
   --Old Location:OKCRVERB.pls
   --New Location:Base Table API

   FUNCTION restore_version(p_chr_id IN NUMBER, p_major_version IN NUMBER)
      RETURN VARCHAR2 IS
   
      l_return_status VARCHAR2(1) := okc_api.g_ret_sts_success;
   
   BEGIN
   
      IF (l_debug = 'Y') THEN
         okc_debug.set_indentation('OKC_CLE_PVT');
         okc_debug.log('23700: Entered restore_version', 2);
      END IF;
   
      INSERT INTO okc_k_lines_tl
         (id,
          LANGUAGE,
          source_lang,
          sfwt_flag,
          NAME,
          comments,
          item_description,
          oke_boe_description,
          cognomen,
          block23text,
          created_by,
          creation_date,
          last_updated_by,
          last_update_date,
          last_update_login)
         SELECT id,
                LANGUAGE,
                source_lang,
                sfwt_flag,
                NAME,
                comments,
                item_description,
                oke_boe_description,
                cognomen,
                block23text,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                last_update_login
           FROM okc_k_lines_tlh
          WHERE id IN
                (SELECT id FROM okc_k_lines_bh WHERE dnz_chr_id = p_chr_id) AND
                major_version = p_major_version;
   
      ------------------------------------------
      -- Restoring Base Table
      ------------------------------------------
   
      INSERT INTO okc_k_lines_b
         (id,
          line_number,
          chr_id,
          cle_id,
          dnz_chr_id,
          display_sequence,
          sts_code,
          trn_code,
          lse_id,
          exception_yn,
          object_version_number,
          created_by,
          creation_date,
          last_updated_by,
          last_update_date,
          hidden_ind,
          price_negotiated,
          price_level_ind,
          price_unit,
          price_unit_percent,
          invoice_line_level_ind,
          dpas_rating,
          template_used,
          price_type,
          --uom_code,
          currency_code,
          last_update_login,
          date_terminated,
          start_date,
          end_date,
          date_renewed,
          orig_system_source_code,
          orig_system_id1,
          orig_system_reference1,
          upg_orig_system_ref,
          upg_orig_system_ref_id,
          request_id,
          program_application_id,
          program_id,
          program_update_date,
          price_list_id,
          pricing_date,
          price_list_line_id,
          line_list_price,
          item_to_price_yn,
          price_basis_yn,
          config_header_id,
          config_revision_number,
          config_complete_yn,
          config_valid_yn,
          config_top_model_line_id,
          config_item_type,
          ---Bug.No.-1942374
          config_item_id,
          ---Bug.No.-1942374
          attribute_category,
          attribute1,
          attribute2,
          attribute3,
          attribute4,
          attribute5,
          attribute6,
          attribute7,
          attribute8,
          attribute9,
          attribute10,
          attribute11,
          attribute12,
          attribute13,
          attribute14,
          attribute15,
          currency_code_renewed,
          price_negotiated_renewed,
          service_item_yn,
          --new columns for price hold
          ph_pricing_type,
          ph_price_break_basis,
          ph_min_qty,
          ph_min_amt,
          ph_qp_reference_id,
          ph_value,
          ph_enforce_price_list_yn,
          ph_adjustment,
          ph_integrated_with_qp,
          --new columns to replace rules
          cust_acct_id,
          bill_to_site_use_id,
          inv_rule_id,
          line_renewal_type_code,
          ship_to_site_use_id,
          payment_term_id,
          payment_instruction_type, --added by mchoudha 22-JUL
          date_cancelled, --added by npalepu 26-JUL -- New columns for Line Level Cancellation
          --canc_reason_code,
          term_cancel_source,
          cancelled_amount,
          annualized_factor --added by npalepu 26-JUL
          )
         SELECT id,
                line_number,
                chr_id,
                cle_id,
                dnz_chr_id,
                display_sequence,
                sts_code,
                trn_code,
                lse_id,
                exception_yn,
                object_version_number,
                created_by,
                creation_date,
                last_updated_by,
                last_update_date,
                hidden_ind,
                price_negotiated,
                price_level_ind,
                price_unit,
                price_unit_percent,
                invoice_line_level_ind,
                dpas_rating,
                template_used,
                price_type,
                --uom_code,
                currency_code,
                last_update_login,
                date_terminated,
                start_date,
                end_date,
                date_renewed,
                orig_system_source_code,
                orig_system_id1,
                orig_system_reference1,
                upg_orig_system_ref,
                upg_orig_system_ref_id,
                request_id,
                program_application_id,
                program_id,
                program_update_date,
                price_list_id,
                pricing_date,
                price_list_line_id,
                line_list_price,
                item_to_price_yn,
                price_basis_yn,
                config_header_id,
                config_revision_number,
                config_complete_yn,
                config_valid_yn,
                config_top_model_line_id,
                config_item_type,
                ---Bug.No.-1942374
                config_item_id,
                ---Bug.No.-1942374
                attribute_category,
                attribute1,
                attribute2,
                attribute3,
                attribute4,
                attribute5,
                attribute6,
                attribute7,
                attribute8,
                attribute9,
                attribute10,
                attribute11,
                attribute12,
                attribute13,
                attribute14,
                attribute15,
                currency_code_renewed,
                price_negotiated_renewed,
                service_item_yn,
                --new columns for price hold
                ph_pricing_type,
                ph_price_break_basis,
                ph_min_qty,
                ph_min_amt,
                ph_qp_reference_id,
                ph_value,
                ph_enforce_price_list_yn,
                ph_adjustment,
                ph_integrated_with_qp,
                -- new columns to replace rules
                cust_acct_id,
                bill_to_site_use_id,
                inv_rule_id,
                line_renewal_type_code,
                ship_to_site_use_id,
                payment_term_id,
                payment_instruction_type, --added by mchoudha 22-JUL
                date_cancelled, --added by npalepu 26-JUL -- New columns for Line Level Cancellation
                --canc_reason_code,
                term_cancel_source,
                cancelled_amount,
                annualized_factor --added by npalepu 26-JUL
         
           FROM okc_k_lines_bh
          WHERE dnz_chr_id = p_chr_id AND
                major_version = p_major_version;
   
      IF (l_debug = 'Y') THEN
         okc_debug.log('23800: Exiting restore_version', 2);
         okc_debug.reset_indentation;
      END IF;
   
      RETURN l_return_status;
   
   EXCEPTION
      -- other appropriate handlers
      WHEN OTHERS THEN
      
         IF (l_debug = 'Y') THEN
            okc_debug.log('23900: Exiting restore_version:OTHERS Exception',
                          2);
            okc_debug.reset_indentation;
         END IF;
      
         -- store SQL error message on message stack
         okc_api.set_message(p_app_name     => okc_version_pvt.g_app_name,
                             p_msg_name     => okc_version_pvt.g_unexpected_error,
                             p_token1       => okc_version_pvt.g_sqlcode_token,
                             p_token1_value => SQLCODE,
                             p_token2       => okc_version_pvt.g_sqlerrm_token,
                             p_token2_value => SQLERRM);
      
         -- notify  UNEXPECTED error
         l_return_status := okc_api.g_ret_sts_unexp_error;
         RETURN l_return_status;
      
   END restore_version;

END xxoks_cle_pvt;
/

