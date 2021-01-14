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

DWORD get_certs(PCCERT_CONTEXT** certs, size_t* count)
{
    PCCERT_CONTEXT userCert = NULL;
    CSP_BOOL bResult = FALSE;
    DWORD            dwSize = 0;
    CRYPT_KEY_PROV_INFO *pProvInfo = NULL;
    DWORD rv = ERROR_SUCCESS;
    std::vector<PCCERT_CONTEXT> certs_vector = std::vector<PCCERT_CONTEXT>();
    
    HCERTSTORE hCertStore = CertOpenSystemStore(0, "My");
    if(!hCertStore){
        rv = CSP_GetLastError();
        std::cerr << "CertOpenSystemStore failed." << std::endl;
        goto exit;
    }
    

    while(true){
        userCert = CertFindCertificateInStore(hCertStore, X509_ASN_ENCODING | PKCS_7_ASN_ENCODING, 0, CERT_FIND_ANY, 0, userCert);
        if(!userCert){
            break;
        }
        bResult = CertGetCertificateContextProperty(userCert,
                    CERT_KEY_PROV_INFO_PROP_ID, NULL, &dwSize);
        if (bResult) {
            free(pProvInfo);
            pProvInfo = (CRYPT_KEY_PROV_INFO *)malloc(dwSize);
            if (pProvInfo) {
                bResult = CertGetCertificateContextProperty(userCert, CERT_KEY_PROV_INFO_PROP_ID, pProvInfo, &dwSize);
                certs_vector.push_back(CertDuplicateCertificateContext(userCert));
            }
        }
    }
    
    free(pProvInfo);
    
    if (!certs_vector.size()) {
        std::cerr << "No certs found" << std::endl;
        rv = ERROR_NO_MORE_ITEMS;
        goto close_cert_store;
    }
    
    *certs = (PCCERT_CONTEXT*) malloc(sizeof(certs_vector[0])* certs_vector.size());
    if (!certs) {
        rv = ERROR_CANNOT_COPY;
        goto close_cert_store;
    }
    
    memcpy(*certs, certs_vector.data(), sizeof(certs_vector[0])*certs_vector.size());
    *count=certs_vector.size();
    
close_cert_store:
    // Закрываем хранилище
    if (!CertCloseStore(hCertStore, 0)) {
        free(*certs);
        *certs = nullptr;
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

