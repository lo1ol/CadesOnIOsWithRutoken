//
//  CadesSign.cpp
//  CAdESSample
//
//  Created by Anatoly Belyaev on 19.11.2020.
//

//#include <stdio.h>
#include <iostream>
#include <vector>
#include <CPROCSP/CPROCSP.h>
#include <CPROPKI/cades.h>
#include "SignFile.h"

extern bool USE_CACHE_DIR;
bool USE_CACHE_DIR = false;
static const int kGostProvType = PROV_GOST_2012_256;



DWORD get_certs(PCCERT_CONTEXT** certs, size_t* count)
{
    DWORD            dwSize = 0;
    *count = 0;
    *certs = NULL;
    CRYPT_KEY_PROV_INFO *pProvInfo = NULL;
    DWORD rv = ERROR_SUCCESS;
    HCRYPTPROV hProv = 0;
    std::vector<PCCERT_CONTEXT> certs_vector = std::vector<PCCERT_CONTEXT>();
    DWORD fParam = CRYPT_FIRST;
    DWORD cnt = 0;
    BYTE* pbCertBlob = 0;
    DWORD dwCertBlob = 0;
    char* contName = NULL;
    PCCERT_CONTEXT certificate = 0;
    PCCERT_CONTEXT certDup = 0;
    
    //
    // 1. Acquire context to enumerate containers.
    //
    if (!CryptAcquireContext(&hProv, NULL, NULL, kGostProvType, CRYPT_VERIFYCONTEXT)) {
        printf("CryptAcquireContext failed\n");
        rv = CSP_GetLastError();
        goto exit;
    }

    //
    // 2. Enumerate containers and collect all CERT_CONTEXTs.
    //
    while (true)
    {
        cnt++;
        HCRYPTKEY hKey;
        HCRYPTPROV hProv2;
        DWORD size = 0;
        DWORD cbProvName;
        LPWSTR pbProvName = NULL;
        CRYPT_KEY_PROV_INFO KeyProvInfo;
        LPWSTR wContName = NULL;
        bool forceStopWhile = false;
        
        if (!CryptGetProvParam(hProv, PP_ENUMCONTAINERS, NULL, &size, fParam)) {
            rv = CSP_GetLastError();
            if (rv == ERROR_NO_MORE_ITEMS) {
                rv = ERROR_SUCCESS;
                forceStopWhile = true;
            }
            goto stop_while;
        }
        
        contName = (char *) malloc(size);
        if (!CryptGetProvParam(hProv, PP_ENUMCONTAINERS, (BYTE *) contName, &size, fParam)) {
            rv = CSP_GetLastError();
            if (rv == ERROR_NO_MORE_ITEMS) {
                rv = ERROR_SUCCESS;
                forceStopWhile = true;
            }
            goto free_cont_name;
        }
        
        fParam = 0;
        
        printf("Container name: %s\n", contName);

        //
        // 3. Start work with a container.
        //
        if(!CryptAcquireContext(&hProv2, (char*) contName, NULL, kGostProvType, NULL)) {
            printf("CryptAcquireContext failed\n");
            rv = CSP_GetLastError();
            goto free_cont_name;
        }

        if (!CryptGetUserKey(hProv2, AT_KEYEXCHANGE, &hKey)) {
            printf("CryptGetUserKey failed\n");
            rv = CSP_GetLastError();
            goto release_context2;
        }

        //
        // Get size of certificate.
        //
        if (!CryptGetKeyParam(hKey, KP_CERTIFICATE, NULL, &dwCertBlob, NULL)) {
            printf("CryptGetKeyParam failed\n");
            rv = CSP_GetLastError();
            goto free_key;
        }

        //
        // Read certificate.
        //
        pbCertBlob = new BYTE[dwCertBlob];
        if (!CryptGetKeyParam(hKey, KP_CERTIFICATE, pbCertBlob, &dwCertBlob, NULL)) {
            printf("Get certificate blob failed\n");
            rv = CSP_GetLastError();
            goto free_cert_blob;
        }

        //
        // Create certificate context from just read binary data.
        //
        certificate = CertCreateCertificateContext( PKCS_7_ASN_ENCODING | X509_ASN_ENCODING, pbCertBlob, dwCertBlob);
        
        if (!certificate) {
            printf("CertCreateCertificateContext failed\n");
            rv = CSP_GetLastError();
            goto free_cert_blob;
        }
        
        if(!CryptGetDefaultProviderW(
            kGostProvType,
            NULL,
            CRYPT_MACHINE_DEFAULT,
            NULL,
            &cbProvName))
        {
            printf("Error getting the length of the default provider name.");
            rv = CSP_GetLastError();
            goto free_cert_context;
        }
        
        pbProvName = new wchar_t[cbProvName];
        if(!CryptGetDefaultProviderW(
            kGostProvType,
            NULL,
            CRYPT_MACHINE_DEFAULT,
            pbProvName,
            &cbProvName))
        {
            printf("Error getting the length of the default provider name.");
            rv = CSP_GetLastError();
            goto free_prov_name;
        }
        
        wContName = new wchar_t[strlen(contName)+1];
        mbstowcs (wContName, contName, strlen(contName)+1);
        
        KeyProvInfo.pwszContainerName = wContName;
        KeyProvInfo.pwszProvName = pbProvName;
        KeyProvInfo.dwProvType = kGostProvType;
        KeyProvInfo.dwKeySpec = AT_KEYEXCHANGE;
        KeyProvInfo.dwFlags = 0;
        KeyProvInfo.cProvParam = 0;
        KeyProvInfo.rgProvParam = NULL;
        
        if (!CertSetCertificateContextProperty(certificate, CERT_KEY_PROV_INFO_PROP_ID, NULL, (void *) &KeyProvInfo)) {
            printf("CertSetCertificateContextProperty error");
            rv = CSP_GetLastError();
            goto free_wcont_name;
        }
        
        certDup = CertDuplicateCertificateContext(certificate);
        if (!certDup) {
            goto free_wcont_name;
        }
        
        certs_vector.push_back(certDup);
       
free_wcont_name:
        delete[] wContName;
        wContName = NULL;
        
free_prov_name:
        delete[] pbProvName;
        pbProvName = NULL;
        
free_cert_context:
        CertFreeCertificateContext(certificate);
        
free_cert_blob:
        delete[] pbCertBlob;
        pbProvName = NULL;
        
free_key:
        CryptDestroyKey(hKey);
        
release_context2:
        CryptReleaseContext(hProv2, 0);
        
free_cont_name:
        free(contName);
        contName = NULL;
        
stop_while:
        if (rv != ERROR_SUCCESS) {
            goto release_context;
        }
        
        if (forceStopWhile) {
            break;
        }
    }
    
    if (!certs_vector.size()) {
        count=0;
        certs = NULL;
        goto release_context;
    }
    
    *certs = (PCCERT_CONTEXT*) malloc(sizeof(certs_vector[0])* certs_vector.size());
    if (!certs) {
        rv = ERROR_CANNOT_COPY;
        goto release_context;
    }
    
    memcpy(*certs, certs_vector.data(), sizeof(certs_vector[0])*certs_vector.size());
    *count=certs_vector.size();
    
release_context:
    // Закрываем хранилище
    if (!CryptReleaseContext(hProv, 0)) {
        free(*certs);
        *certs = nullptr;
        count = 0;
        std::cout << "Certificate store handle was not closed." << std::endl;
        rv = CSP_GetLastError();
    }
    
exit:
    return rv;
}

static DWORD VerifyCertificate(PCCERT_CONTEXT pCert,DWORD *CheckResult)
{
    CERT_CHAIN_PARA ChainPara;
    PCCERT_CHAIN_CONTEXT Chain=NULL;
    
    ChainPara.cbSize=sizeof(ChainPara);
    ChainPara.RequestedUsage.dwType=USAGE_MATCH_TYPE_AND;
    ChainPara.RequestedUsage.Usage.cUsageIdentifier=0;
    ChainPara.RequestedUsage.Usage.rgpszUsageIdentifier=NULL;
    //ChainPara.RequestedIssuancePolicy=NULL;
    //ChainPara.fCheckRevocationFreshnessTime=FALSE;
    //ChainPara.dwUrlRetrievalTimeout=0;
    
    if(!CertGetCertificateChain(
                                NULL,
                                pCert,
                                NULL,
                                NULL,//?
                                &ChainPara,
                                CERT_CHAIN_REVOCATION_CHECK_CHAIN_EXCLUDE_ROOT,
                                NULL,
                                &Chain))
        return CSP_GetLastError();
    *CheckResult=Chain->TrustStatus.dwErrorStatus;
    if(Chain)
        CertFreeCertificateChain(Chain);
    return 0;
}

// Функция получения OID алгоритма хеширования по сертификату
static const char* GetHashOid(const PCCERT_CONTEXT pCert) {
    const char *pKeyAlg = pCert->pCertInfo->SubjectPublicKeyInfo.Algorithm.pszObjId;
    if (strcmp(pKeyAlg, szOID_CP_GOST_R3410EL) == 0)
    {
        return szOID_CP_GOST_R3411;
    }
    else if (strcmp(pKeyAlg, szOID_CP_GOST_R3410_12_256) == 0)
    {
        return szOID_CP_GOST_R3411_12_256;
    }
    else if (strcmp(pKeyAlg, szOID_CP_GOST_R3410_12_512) == 0)
    {
        return szOID_CP_GOST_R3411_12_512;
    }
    return NULL;
}

const wchar_t *GetWC(const char *c)
{
    const size_t cSize = strlen(c)+1;
    wchar_t* wc = new wchar_t[cSize];
    mbstowcs (wc, c, cSize);

    return wc;
}

DWORD do_low_sign(const char* pin, const uint8_t* msg, size_t msg_size, const PCCERT_CONTEXT _context, const char* tsp, char** signature)
{
    
    const LPCWSTR w_tsp = GetWC(tsp);
    DWORD dwLen = 0;
    DWORD rv = ERROR_SUCCESS;
    
    CRYPT_SIGN_MESSAGE_PARA signPara = {sizeof(signPara)};
    CADES_SIGN_PARA cadesSignPara = {sizeof(cadesSignPara)};
    CADES_SERVICE_CONNECTION_PARA tspConnectionPara = {sizeof(tspConnectionPara)};
    CADES_SIGN_MESSAGE_PARA para = {sizeof(para)};
    const unsigned char *pbToBeSigned[] = {msg};
    
    DWORD cbToBeSigned[] = {(DWORD) msg_size};
    CERT_CHAIN_PARA        ChainPara = {sizeof(ChainPara)};
    PCCERT_CHAIN_CONTEXT    pChainContext = NULL;
    PCRYPT_DATA_BLOB pSignedMessage = 0;
    DWORD i;
    
    std::vector<PCCERT_CONTEXT> certs;
    *signature = 0;
    
    PCCERT_CONTEXT context;
    
    CRYPT_KEY_PROV_INFO *provInfo = NULL;
    DWORD            dwSize;
    
    // Если сертификат не найден, завершаем работу
    if (!_context) {
        std::cerr << "No certificate context passed" << std::endl;
        rv = ERROR_BAD_ARGUMENTS;
        goto free_tsp;
    }
    
    context = CertDuplicateCertificateContext(_context);
    
    if (!context) {
        std::cerr << "Can't duplicate certificate context" << std::endl;
        rv = CSP_GetLastError();
        goto free_tsp;
    }
    
    if (pin) {
        if (!CertGetCertificateContextProperty(context, CERT_KEY_PROV_INFO_PROP_ID, NULL, &dwSize)) {
                std::cerr << "Can't get CERT_KEY_PROV_INFO_PROP_ID of cert" << std::endl;
                rv = CSP_GetLastError();
                goto free_context;
        }
        
        provInfo = (CRYPT_KEY_PROV_INFO *) malloc(dwSize);
        
        if (!CertGetCertificateContextProperty(context, CERT_KEY_PROV_INFO_PROP_ID, provInfo, &dwSize)) {
            std::cerr << "Can't get CERT_KEY_PROV_INFO_PROP_ID of cert" << std::endl;
            rv = CSP_GetLastError();
            goto free_prov_info;
        }
        
        CRYPT_KEY_PROV_PARAM key_prov_param;
        DWORD cbPin = strlen(pin) + 1;
    
        key_prov_param.dwParam = PP_KEYEXCHANGE_PIN;
        key_prov_param.cbData = cbPin;
        key_prov_param.pbData = (uint8_t *) pin;
        
        provInfo->cProvParam = 1;
        provInfo->rgProvParam = &key_prov_param;
        
        if (!CertSetCertificateContextProperty(context, CERT_KEY_PROV_INFO_PROP_ID, NULL, provInfo)) {
            std::cerr << "Can't set CERT_KEY_PROV_INFO_PROP_ID of cert" << std::endl;
            rv = CSP_GetLastError();
            goto free_prov_info;
        }
    }
    
    // Задаем параметры
    signPara.dwMsgEncodingType = X509_ASN_ENCODING | PKCS_7_ASN_ENCODING;
    signPara.pSigningCert = context;
    signPara.HashAlgorithm.pszObjId = (LPSTR) GetHashOid(context);
    
    cadesSignPara.dwCadesType = CADES_X_LONG_TYPE_1; //Указываем тип проверяемой подписи CADES_BES или CADES_X_LOGNG_TYPE_1
    tspConnectionPara.wszUri = w_tsp;
    cadesSignPara.pTspConnectionPara = &tspConnectionPara;
    
    para.pSignMessagePara = &signPara;
    para.pCadesSignPara = &cadesSignPara;
    
    
    if (!CertGetCertificateChain(NULL, context, NULL, NULL, &ChainPara, 0, NULL, &pChainContext)) {
        std::cerr << "Can't get certificate chain" << std::endl;
        rv = CSP_GetLastError();
        goto free_prov_info;
    }
    
    for (i = 0; i < pChainContext->rgpChain[0]->cElement-1; ++i)
    {
        certs.push_back(pChainContext->rgpChain[0]->rgpElement[i]->pCertContext);
    }
        
    // Добавляем в сообщение цепочку сертификатов кроме корневого
    if (certs.size() > 0)
    {
        signPara.cMsgCert = (DWORD)certs.size();
        signPara.rgpMsgCert = certs.data();
    }
    
    // Создаем подписанное сообщение
    if (!CadesSignMessage(&para, 0, 1, pbToBeSigned, cbToBeSigned, &pSignedMessage)) {
        std::cerr << "CadesSignMessage() failed" << std::endl;
        rv = CSP_GetLastError();
        goto free_cert_chain;
    }
    
    if (!CryptBinaryToStringA(pSignedMessage->pbData, pSignedMessage->cbData, CRYPT_STRING_BASE64, nullptr, &dwLen)) {
        std::cerr << "Error in decode signature to base64" << std::endl;
        rv = CSP_GetLastError();
        goto free_signature_blob;
    }
    
    *signature = (char *) malloc(dwLen);
    
    if (!CryptBinaryToStringA(pSignedMessage->pbData, pSignedMessage->cbData, CRYPT_STRING_BASE64, *signature, &dwLen)) {
        std::cerr << "Error in decode signature to base64" << std::endl;
        rv = CSP_GetLastError();
        goto free_signature;
    }
    
    (*signature)[dwLen] = 0;
    
free_signature:
    if (rv) free(*signature);
    
free_signature_blob:
    CadesFreeBlob(pSignedMessage);

free_cert_chain:
    CertFreeCertificateChain(pChainContext);
    
free_prov_info:
    if (provInfo) free(provInfo);
    
free_context:
    CertFreeCertificateContext(context);
    
free_tsp:
    delete[] (w_tsp);

exit:
    return rv;
}

DWORD do_low_verify(const char* signature, DWORD* verificationStatus)
{
    // Задаем параметры проверки
    CRYPT_VERIFY_MESSAGE_PARA cryptVerifyPara = { sizeof(cryptVerifyPara) };
    cryptVerifyPara.dwMsgAndCertEncodingType = X509_ASN_ENCODING | PKCS_7_ASN_ENCODING;
    
    CADES_VERIFICATION_PARA cadesVerifyPara = { sizeof(cadesVerifyPara) };
    cadesVerifyPara.dwCadesType = CADES_X_LONG_TYPE_1; // Указываем тип проверяемой подписи CADES_BES или CADES_X_LOGNG_TYPE_1
    
    CADES_VERIFY_MESSAGE_PARA verifyPara = { sizeof(verifyPara) };
    verifyPara.pVerifyMessagePara = &cryptVerifyPara;
    verifyPara.pCadesVerifyPara = &cadesVerifyPara;
    
    PCADES_VERIFICATION_INFO pVerifyInfo = 0;
    PCRYPT_DATA_BLOB pContent = 0;
    
    std::vector<unsigned char> message;
    
    DWORD dwLen = 0;
    DWORD rv = ERROR_SUCCESS;
    
    if (!CryptStringToBinaryA(signature, (DWORD)strlen(signature), CRYPT_STRING_BASE64_ANY, NULL, &dwLen, NULL, NULL)) {
        std::cerr << "Error in decode from base64" << std::endl;
        rv = CSP_GetLastError();
        goto exit;
    }
    
    message.resize(dwLen);
    if (!CryptStringToBinaryA(signature, (DWORD)strlen(signature), CRYPT_STRING_BASE64_ANY, &message[0], &dwLen, NULL, NULL)) {
        std::cerr << "Error in decode from base64" << std::endl;
        rv = CSP_GetLastError();
        goto exit;
    }
    message.resize(dwLen);
    
    // Проверяем подпись
    if (!CadesVerifyMessage(&verifyPara, 0, &message[0], (DWORD)message.size(), &pContent, &pVerifyInfo))
    {
        std::cerr << "CadesVerifyMessage() failed" << std::endl;
        rv = CSP_GetLastError();
        goto free_verification_info;
    }
    
    // Выводим результат проверки
    if (pVerifyInfo->dwStatus != CADES_VERIFY_SUCCESS)
        std::cerr << "Message is not verified successfully." << std::endl;
    else
        std::cerr << "Message verified successfully." << std::endl;
    
    *verificationStatus = pVerifyInfo->dwStatus;
    
free_cades_blob:
    CadesFreeBlob(pContent);
    
free_verification_info:
    CadesFreeVerificationInfo(pVerifyInfo);
    
exit:
    return rv;
}

